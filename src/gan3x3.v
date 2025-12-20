// File         : gan3x3.v
// Description  : GAN 3x3 module

`timescale 1ns/1ps

`include "memory.v"
`include "pe_neuron.v"

module gan3x3 #(
    parameter DATA_WIDTH = 32
) (
    input wire clk,
    input wire rst,
    input wire start,
    input wire signed [DATA_WIDTH-1:0] noise_in1,
    input wire signed [DATA_WIDTH-1:0] noise_in2,
    output reg signed [DATA_WIDTH-1:0] disc_out,
    output reg done
);
    // Internal RAM and address
    reg signed [DATA_WIDTH-1:0] internal_ram [0:15];
    reg [9:0] mem_addr;

    // Weight outputs from memory and PE I/O
    wire signed [DATA_WIDTH-1:0] w1, w2, w3, w4, bias;
    reg signed [DATA_WIDTH-1:0] pe_x1, pe_x2, pe_x3, pe_x4;
    reg signed [DATA_WIDTH-1:0] pe_partial_sum;
    wire signed [DATA_WIDTH-1:0] pe_result;

    // PE control: accumulation and activation select
    reg pe_accumulate;
    reg [1:0] pe_act_sel; // 0=tanh, 1=sigmoid, 2=alternate tanh

    memory #(.DATA_WIDTH(DATA_WIDTH)) u_mem (
        .clk (clk), .addr(mem_addr),
        .w1(w1), .w2(w2), .w3(w3), .w4(w4), .bias(bias)
    );

    pe_neuron #(.DATA_WIDTH(DATA_WIDTH)) u_pe (
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

    // Control states
    localparam S_IDLE = 3'd0;
    localparam S_GEN_HIDDEN = 3'd1;
    localparam S_GEN_OUTPUT = 3'd2;
    localparam S_DIS_HIDDEN = 3'd3;
    localparam S_DIS_OUTPUT = 3'd4;
    localparam S_DONE = 3'd5;

    reg [2:0] state;
    reg [3:0] loop_cnt;
    reg [1:0] acc_step;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            state <= S_IDLE;
            mem_addr <= 0;
            done <= 0;
            loop_cnt <= 0;
            acc_step <= 0;
            pe_partial_sum <= 0;
            pe_x1 <= 0;
            pe_x2 <= 0;
            pe_x3 <= 0;
            pe_x4 <= 0;
            pe_accumulate <= 0;
            pe_act_sel <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= S_GEN_HIDDEN;
                        mem_addr <= 0;
                        loop_cnt <= 0;

                        // Seed generator hidden inputs with noise
                        pe_x1 <= noise_in1;
                        pe_x2 <= noise_in2;
                        pe_x3 <= 0;
                        pe_x4 <= 0;
                        pe_act_sel <= 0; // tanh
                        pe_accumulate <= 0;
                    end
                end
            
                S_GEN_HIDDEN: begin
                    internal_ram[loop_cnt] <= pe_result;

                    if (loop_cnt == 2) begin
                        state <= S_GEN_OUTPUT;
                        loop_cnt <= 0;
                        mem_addr <= mem_addr + 1;

                        // Prepare inputs for generator output stage
                        pe_x1 <= internal_ram[0];
                        pe_x2 <= internal_ram[1];
                        pe_x3 <= pe_result;
                        pe_x4 <= 0;
                        pe_act_sel <= 0;
                        pe_accumulate <= 0;
                    end else begin
                        loop_cnt <= loop_cnt + 1;
                        mem_addr <= mem_addr + 1;
                        pe_x1 <= noise_in1;
                        pe_x2 <= noise_in2;
                        pe_x3 <= 0;
                        pe_x4 <= 0;
                    end
                end

                S_GEN_OUTPUT: begin
                    internal_ram[3 + loop_cnt] <= pe_result;

                    if (loop_cnt == 8) begin
                        state <= S_DIS_HIDDEN;
                        loop_cnt <= 0;
                        acc_step <= 0;
                        mem_addr <= mem_addr + 1;

                        // Load discriminator hidden inputs
                        pe_x1 <= internal_ram[3];
                        pe_x2 <= internal_ram[4];
                        pe_x3 <= internal_ram[5];
                        pe_x4 <= internal_ram[6];
                        pe_act_sel <= 2; // tanh variant
                        pe_accumulate <= 0;
                    end else begin
                        loop_cnt <= loop_cnt + 1;
                        mem_addr <= mem_addr + 1;

                        // Use generator hidden outputs as inputs
                        pe_x1 <= internal_ram[0];
                        pe_x2 <= internal_ram[1];
                        pe_x3 <= internal_ram[2];
                        pe_x4 <= 0;
                    end
                end

                S_DIS_HIDDEN: begin
                    // Discriminator hidden: accumulate over three passes
                    case (acc_step)
                        0: begin
                            // Save partial sum and set inputs for pass 2
                            pe_partial_sum <= pe_result;
                            acc_step <= 1;
                            mem_addr <= mem_addr + 1;
                            pe_x1 <= internal_ram[7];
                            pe_x2 <= internal_ram[8];
                            pe_x3 <= internal_ram[9];
                            pe_x4 <= internal_ram[10];
                            pe_accumulate <= 1;
                        end

                        1: begin
                            // Save partial sum and load remaining inputs
                            pe_partial_sum <= pe_result;
                            acc_step <= 2;
                            mem_addr <= mem_addr + 1;
                            pe_x1 <= internal_ram[11];
                            pe_x2 <= 0;
                            pe_x3 <= 0;
                            pe_x4 <= 0;
                            pe_act_sel <= 0;
                            pe_accumulate <= 1;
                        end
                        
                        2: begin
                            // Final pass: write result to RAM
                            internal_ram[12 + loop_cnt] <= pe_result;

                            if (loop_cnt == 2) begin
                                // Move to discriminator output stage
                                state <= S_DIS_OUTPUT;
                                loop_cnt <= 0;
                                mem_addr <= mem_addr + 1;

                                // Load D3 inputs
                                pe_x1 <= internal_ram[12];
                                pe_x2 <= internal_ram[13];
                                pe_x3 <= pe_result;
                                pe_x4 <= 0;
                                pe_act_sel <= 1; // sigmoid
                                pe_accumulate <= 0;
                            end else begin
                                // Prepare next hidden neuron
                                loop_cnt <= loop_cnt + 1;
                                acc_step <= 0;
                                mem_addr <= mem_addr + 1;
                                pe_x1 <= internal_ram[3];
                                pe_x2 <= internal_ram[4];
                                pe_x3 <= internal_ram[5];
                                pe_x4 <= internal_ram[6];
                                pe_act_sel <= 2;
                                pe_accumulate <= 0;
                            end
                        end
                    endcase
                end

                S_DIS_OUTPUT: begin
                    disc_out <= pe_result;
                    state <= S_DONE;
                end

                S_DONE: begin
                    done <= 1;
                    if (!start) state <= S_IDLE;
                end
            endcase
        end
    end

endmodule