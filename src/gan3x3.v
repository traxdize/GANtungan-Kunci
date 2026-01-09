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

    // Internal ram debug temporary signals
    // output wire [DATA_WIDTH-1:0] ram_out_0,
    // output wire [DATA_WIDTH-1:0] ram_out_1,
    // output wire [DATA_WIDTH-1:0] ram_out_2,
    // output wire [DATA_WIDTH-1:0] ram_out_3,
    // output wire [DATA_WIDTH-1:0] ram_out_4,
    // output wire [DATA_WIDTH-1:0] ram_out_5,
    // output wire [DATA_WIDTH-1:0] ram_out_6,
    // output wire [DATA_WIDTH-1:0] ram_out_7,
    // output wire [DATA_WIDTH-1:0] ram_out_8,
    // output wire [DATA_WIDTH-1:0] ram_out_9,
    // output wire [DATA_WIDTH-1:0] ram_out_10,
    // output wire [DATA_WIDTH-1:0] ram_out_11,
    // output wire [DATA_WIDTH-1:0] ram_out_12,
    // output wire [DATA_WIDTH-1:0] ram_out_13,
    // output wire [DATA_WIDTH-1:0] ram_out_14,
    // output wire [DATA_WIDTH-1:0] ram_out_15
);
    // --- RAM ---
    reg signed [DATA_WIDTH-1:0] internal_ram [0:15];
    reg [9:0] mem_addr;

    // Internal ram debug temporary signals
    // assign ram_out_0 = internal_ram[0];
    // assign ram_out_1 = internal_ram[1];
    // assign ram_out_2 = internal_ram[2];
    // assign ram_out_3 = internal_ram[3];
    // assign ram_out_4 = internal_ram[4];
    // assign ram_out_5 = internal_ram[5];
    // assign ram_out_6 = internal_ram[6];
    // assign ram_out_7 = internal_ram[7];
    // assign ram_out_8 = internal_ram[8];
    // assign ram_out_9 = internal_ram[9];
    // assign ram_out_10 = internal_ram[10];
    // assign ram_out_11 = internal_ram[11];
    // assign ram_out_12 = internal_ram[12];
    // assign ram_out_13 = internal_ram[13];
    // assign ram_out_14 = internal_ram[14];
    // assign ram_out_15 = internal_ram[15];
    
    // --- Weights & PE signals ---
    wire signed [DATA_WIDTH-1:0] w1, w2, w3, w4, bias;
    reg signed [DATA_WIDTH-1:0] pe_x1, pe_x2, pe_x3, pe_x4;
    reg signed [DATA_WIDTH-1:0] pe_partial_sum;
    wire signed [DATA_WIDTH-1:0] pe_result;
    
    // --- Control ---
    reg pe_accumulate;
    reg [1:0] pe_act_sel; // 0 -> tanh, 1 -> sigmoid

    // --- Pipeline Control ---
    reg [1:0] pipe_cnt;
    localparam [1:0] PIPE_WAIT = 2'd3; // Kontrol pipeline

    // --- Instantiations ---
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

    // State
    localparam S_IDLE       = 3'd0;
    localparam S_GEN_HIDDEN = 3'd1;
    localparam S_GEN_OUTPUT = 3'd2;
    localparam S_DIS_HIDDEN = 3'd3;
    localparam S_DIS_OUTPUT = 3'd4;
    localparam S_DONE       = 3'd5;

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
            pipe_cnt <= 0;
            pe_partial_sum <= 0;
            pe_x1 <= 0; pe_x2 <= 0; pe_x3 <= 0; pe_x4 <= 0;
            pe_accumulate <= 0;
            pe_act_sel <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if(start) begin
                        state <= S_GEN_HIDDEN;
                        mem_addr <= 0;
                        loop_cnt <= 0;
                        pipe_cnt <= 0; // Reset pipe counter
                        
                        pe_x1 <= noise_in1;
                        pe_x2 <= noise_in2;
                        pe_x3 <= 0;
                        pe_x4 <= 0;
                        pe_act_sel <= 0; // Tanh
                        pe_accumulate <= 0;
                    end
                end
            
                S_GEN_HIDDEN: begin
                    // Tunggu pipeline
                    if (pipe_cnt < PIPE_WAIT) begin
                        pipe_cnt <= pipe_cnt + 1;
                    end else begin
                        internal_ram[loop_cnt] <= pe_result;
                        pipe_cnt <= 0; // Reset counter pipeline

                        if (loop_cnt == 2) begin
                            state <= S_GEN_OUTPUT;
                            loop_cnt <= 0;
                            mem_addr <= mem_addr + 1;
                            
                            pe_x1 <= internal_ram[0];
                            pe_x2 <= internal_ram[1];
                            pe_x3 <= pe_result; // preload
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
                end

                S_GEN_OUTPUT: begin
                    // Tunggu pipeline
                    if (pipe_cnt < PIPE_WAIT) begin
                        pipe_cnt <= pipe_cnt + 1;
                    end else begin

                        internal_ram[3+loop_cnt] <= pe_result;
                        pipe_cnt <= 0; 

                        if (loop_cnt == 8) begin
                            state <= S_DIS_HIDDEN;
                            loop_cnt <= 0;
                            acc_step <= 0;
                            mem_addr <= mem_addr + 1;
                            
                            // Inputs: Pixel 0-3 (RAM 3,4,5,6)
                            pe_x1 <= internal_ram[3];
                            pe_x2 <= internal_ram[4];
                            pe_x3 <= internal_ram[5];
                            pe_x4 <= internal_ram[6];
                            pe_act_sel <= 2; // bypass
                            pe_accumulate <= 0;
                        end else begin
                            loop_cnt <= loop_cnt + 1;
                            mem_addr <= mem_addr + 1;
                            
                            pe_x1 <= internal_ram[0];
                            pe_x2 <= internal_ram[1];
                            pe_x3 <= internal_ram[2];
                            pe_x4 <= 0;
                        end
                    end
                end

                S_DIS_HIDDEN: begin
                    
                    if (pipe_cnt < PIPE_WAIT) begin
                        pipe_cnt <= pipe_cnt + 1;
                    end else begin
                        pipe_cnt <= 0;

                        case (acc_step)
                            0: begin
                                pe_partial_sum <= pe_result;
                                
                                acc_step <= 1;
                                mem_addr <= mem_addr + 1;
                                
                                pe_x1 <= internal_ram[7];
                                pe_x2 <= internal_ram[8];
                                pe_x3 <= internal_ram[9];
                                pe_x4 <= internal_ram[10];
                                pe_accumulate <= 1; // Akumulasi
                            end

                            1: begin
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
                                internal_ram[12+loop_cnt] <= pe_result;
                                
                                if(loop_cnt == 2) begin
                                    state <= S_DIS_OUTPUT;
                                    loop_cnt <= 0;
                                    mem_addr <= mem_addr + 1;
                                    
                                    //RAM 12, 13, 14
                                    pe_x1 <= internal_ram[12];
                                    pe_x2 <= internal_ram[13];
                                    pe_x3 <= pe_result;
                                    pe_x4 <= 0;
                                    pe_act_sel <= 1; // Sigmoid
                                    pe_accumulate <= 0;
                                end else begin
                                    loop_cnt <= loop_cnt + 1;
                                    acc_step <= 0;
                                    mem_addr <= mem_addr + 1;
                                    
                                    // Pass 0
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
                end

                S_DIS_OUTPUT: begin
                    if (pipe_cnt < PIPE_WAIT) begin
                        pipe_cnt <= pipe_cnt + 1;
                    end else begin
                        // Final Output
                        disc_out <= pe_result;
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    done <= 1;
                    if (!start) state <= S_IDLE;
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule