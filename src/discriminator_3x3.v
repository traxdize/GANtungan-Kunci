// File: discriminator_3x3.v
`timescale 1ns/1ps

`include "memory.v"
`include "pe_neuron.v"

module discriminator_3x3 #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10
)(
    input wire clk,
    input wire rst,
    input wire start,
    // Input: 3x3 Flattened Image (9 pixels)
    input wire signed [DATA_WIDTH-1:0] p1, p2, p3,
    input wire signed [DATA_WIDTH-1:0] p4, p5, p6,
    input wire signed [DATA_WIDTH-1:0] p7, p8, p9,
    
    output reg signed [DATA_WIDTH-1:0] disc_out,
    output reg done
);

    // --- Internal Memory for Intermediate Results ---
    // 0-2: Discriminator Hidden Layer Outputs (D2)
    reg signed [DATA_WIDTH-1:0] hidden_ram [0:2]; 
    
    // --- Input Buffer ---
    reg signed [DATA_WIDTH-1:0] img_buffer [0:8];

    // --- State Machine ---
    localparam S_IDLE       = 3'd0;
    localparam S_LOAD       = 3'd1;
    localparam S_D_HIDDEN   = 3'd2;
    localparam S_D_OUTPUT   = 3'd3;
    localparam S_DONE       = 3'd4;
    
    reg [2:0] state;
    reg [3:0] loop_cnt;  // Neuron counter
    reg [1:0] acc_step;  // Accumulation step for PE

    // --- PE and Memory Signals ---
    reg [ADDR_WIDTH-1:0] mem_addr;
    wire signed [DATA_WIDTH-1:0] w1, w2, w3, w4, bias;
    
    reg signed [DATA_WIDTH-1:0] pe_x1, pe_x2, pe_x3, pe_x4;
    reg signed [DATA_WIDTH-1:0] pe_partial_sum;
    reg pe_accumulate;
    reg [1:0] pe_act_sel; // 0:None, 1:Tanh, 2:Sigmoid
    wire signed [DATA_WIDTH-1:0] pe_result;

    // --- Instantiations ---

    // Weight Memory (Assumed existing module)
    memory u_mem (
        .clk(clk),
        .addr(mem_addr),
        .w1(w1), .w2(w2), .w3(w3), .w4(w4), .bias(bias)
    );

    // Processing Element (Assumed existing module)
    pe_neuron u_pe (
        .clk(clk),
        .rst(rst),
        .x1(pe_x1), .x2(pe_x2), .x3(pe_x3), .x4(pe_x4),
        .w1(w1), .w2(w2), .w3(w3), .w4(w4),
        .bias(bias),
        .pe_accumulate(pe_accumulate),
        .partial_sum_in(pe_partial_sum),
        .act_sel(pe_act_sel),
        .y_out(pe_result)
    );

    // --- Logic ---

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            done <= 0;
            loop_cnt <= 0;
            acc_step <= 0;
            mem_addr <= 0;
            disc_out <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) state <= S_LOAD;
                end

                // Latch inputs into buffer
                S_LOAD: begin
                    img_buffer[0] <= p1; img_buffer[1] <= p2; img_buffer[2] <= p3;
                    img_buffer[3] <= p4; img_buffer[4] <= p5; img_buffer[5] <= p6;
                    img_buffer[6] <= p7; img_buffer[7] <= p8; img_buffer[8] <= p9;
                    
                    state <= S_D_HIDDEN;
                    loop_cnt <= 0; // Target 3 hidden neurons
                    acc_step <= 0;
                    // Start address for D-Hidden weights (Assuming offset 12 based on original code usage)
                    mem_addr <= 12; 
                end

                // Calculate D Hidden Layer (3 Neurons, 9 Inputs each)
                S_D_HIDDEN: begin
                    // Activation: Tanh (1)
                    pe_act_sel <= 1; 

                    // Step 0: Inputs 0-3
                    if (acc_step == 0) begin
                        pe_accumulate <= 0;
                        pe_partial_sum <= 0;
                        pe_x1 <= img_buffer[0]; pe_x2 <= img_buffer[1]; 
                        pe_x3 <= img_buffer[2]; pe_x4 <= img_buffer[3];
                        acc_step <= 1;
                    end 
                    // Step 1: Inputs 4-7
                    else if (acc_step == 1) begin
                        pe_accumulate <= 1;
                        pe_partial_sum <= pe_result; // Feed back previous result
                        pe_x1 <= img_buffer[4]; pe_x2 <= img_buffer[5]; 
                        pe_x3 <= img_buffer[6]; pe_x4 <= img_buffer[7];
                        acc_step <= 2;
                    end 
                    // Step 2: Input 8 (Pad rest with 0)
                    else if (acc_step == 2) begin
                        pe_accumulate <= 1;
                        pe_partial_sum <= pe_result;
                        pe_x1 <= img_buffer[8]; pe_x2 <= 0; 
                        pe_x3 <= 0; pe_x4 <= 0;
                        
                        // Latch result to hidden RAM
                        hidden_ram[loop_cnt] <= pe_result;
                        
                        // Prepare for next neuron or next state
                        if (loop_cnt == 2) begin
                            state <= S_D_OUTPUT;
                            loop_cnt <= 0;
                            acc_step <= 0;
                            mem_addr <= 15; // Address for Output neuron weights
                        end else begin
                            loop_cnt <= loop_cnt + 1;
                            mem_addr <= mem_addr + 1;
                            acc_step <= 0;
                        end
                    end
                end

                // Calculate D Output Layer (1 Neuron, 3 Inputs)
                S_D_OUTPUT: begin
                    // Activation: Sigmoid (2)
                    pe_act_sel <= 2;
                    
                    // Single step computation (3 inputs fit in one PE cycle)
                    pe_accumulate <= 0;
                    pe_partial_sum <= 0;
                    pe_x1 <= hidden_ram[0];
                    pe_x2 <= hidden_ram[1];
                    pe_x3 <= hidden_ram[2];
                    pe_x4 <= 0;

                    // Note: We need one cycle for the PE to compute the final result
                    if (acc_step == 0) begin
                        acc_step <= 1; 
                    end else begin
                        disc_out <= pe_result;
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    done <= 1;
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule