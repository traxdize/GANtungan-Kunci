`timescale 1ns/1ps
`include "sigmoid_lut.v"
`include "tanh_lut.v"

module pe_neuron #(
    parameter DATA_WIDTH = 32
) (
    input wire clk,
    input wire rst,
    input signed [DATA_WIDTH-1:0] x1, x2, x3, x4,
    input signed [DATA_WIDTH-1:0] w1, w2, w3, w4,
    input signed [DATA_WIDTH-1:0] bias,
    
    input wire pe_accumulate,
    input wire signed [DATA_WIDTH-1:0] partial_sum_in,
    input wire [1:0] act_sel,

    output reg signed [DATA_WIDTH-1:0] y_out
);
    // 1. Multiply (FORCE 64-BIT PRECISION)
    // We multiply to 64 bits, then shift, then take the bottom 32 bits
    wire signed [2*DATA_WIDTH-1:0] p1_long = x1 * w1;
    wire signed [2*DATA_WIDTH-1:0] p2_long = x2 * w2;
    wire signed [2*DATA_WIDTH-1:0] p3_long = x3 * w3;
    wire signed [2*DATA_WIDTH-1:0] p4_long = x4 * w4;

    wire signed [DATA_WIDTH-1:0] p1 = p1_long >>> 16;
    wire signed [DATA_WIDTH-1:0] p2 = p2_long >>> 16;
    wire signed [DATA_WIDTH-1:0] p3 = p3_long >>> 16;
    wire signed [DATA_WIDTH-1:0] p4 = p4_long >>> 16;

    // 2. Summation
    reg signed [DATA_WIDTH-1:0] sum_raw;

    always @(*) begin
        sum_raw = p1 + p2 + p3 + p4 + bias;
        if (pe_accumulate) begin
            sum_raw = sum_raw + partial_sum_in;
        end
    end

    // 3. LUT Conversion
    wire signed [31:0] sum_shifted = sum_raw >>> 8;
    wire [15:0] lut_input;
    
    assign lut_input = (sum_shifted > 32'sd32767)  ? 16'h7FFF :
                       (sum_shifted < -32'sd32768) ? 16'h8000 :
                                                     sum_shifted[15:0];

    wire [15:0] tanh_out_16, sig_out_16;
    tanh_lut u_tanh (.z_q1_7_8(lut_input), .a_tanh(tanh_out_16));
    sigmoid_lut u_sig (.z_q1_7_8(lut_input), .a_sigmoid(sig_out_16));

    wire signed [31:0] tanh_out_32 = $signed(tanh_out_16) <<< 8;
    wire signed [31:0] sig_out_32  = $signed(sig_out_16)  <<< 8;

    // 4. Output Logic
    always @(*) begin
        case (act_sel)
            2'd0: y_out = tanh_out_32; // Tanh
            2'd1: y_out = sig_out_32;  // Sigmoid
            default: y_out = sum_raw;  // Linear
        endcase
    end

endmodule