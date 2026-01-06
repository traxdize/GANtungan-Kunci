// File         : compute_core.v
// Description  : Integrates Line Buffer, PE, and Activations.
//                Supports PReLU, LeakyReLU, Tanh, and Sigmoid.
// Standard     : Verilog-2001

`include "line_buffer.v"
`include "pe_conv3x3.v"
`include "tanh_lut.v"
`include "sigmoid_lut.v"

module compute_core (
    input  clk,
    input  rst_n,
    input  en,
    
    // Configuration
    input  [5:0]  img_width,
    input  [1:0]  act_type,     // 0: PReLU/LeakyReLU, 1: Tanh, 2: Sigmoid, 3: None
    input  signed [31:0] slope, // For PReLU/LeakyReLU
    
    // Data I/O
    input  signed [31:0] pixel_in,
    input  valid_in,
    input  signed [31:0] w0, w1, w2, w3, w4, w5, w6, w7, w8,
    input  signed [31:0] bias,
    
    output signed [31:0] pixel_out,
    output valid_out
);

    // Internal Wires
    wire signed [31:0] p [0:8];
    wire window_ready;
    wire signed [31:0] conv_result;
    wire conv_valid;
    
    // LUT Wires
    wire signed [31:0] tanh_out;
    wire signed [31:0] sigmoid_out;

    // 1. Line Buffer Instance
    line_buffer lbuf_inst (
        .clk(clk), .rst_n(rst_n), .en(en),
        .img_width(img_width),
        .pixel_in(pixel_in),
        .valid_in(valid_in),
        .p0(p[0]), .p1(p[1]), .p2(p[2]), 
        .p3(p[3]), .p4(p[4]), .p5(p[5]), 
        .p6(p[6]), .p7(p[7]), .p8(p[8]),
        .window_ready(window_ready)
    );

    // 2. Convolution PE Instance
    pe_conv3x3 pe_inst (
        .clk(clk), .rst_n(rst_n), .en(en),
        .p0(p[0]), .p1(p[1]), .p2(p[2]), 
        .p3(p[3]), .p4(p[4]), .p5(p[5]), 
        .p6(p[6]), .p7(p[7]), .p8(p[8]),
        .w0(w0), .w1(w1), .w2(w2), 
        .w3(w3), .w4(w4), .w5(w5), 
        .w6(w6), .w7(w7), .w8(w8),
        .bias(bias),
        .result(conv_result),
        .valid_out(conv_valid)
    );

    // 3. Activation Logic
    // PReLU/LeakyReLU logic (Fixed Point Q16.16)
    wire signed [63:0] leaky_prod = conv_result * slope;
    wire signed [31:0] leaky_val  = leaky_prod[47:16];
    wire signed [31:0] act_leaky  = (conv_result < 0) ? leaky_val : conv_result;

    // LUT Instantiations (Provided by user)
    tanh_lut tanh_inst (
        .z_in(conv_result),
        .a_tanh(tanh_out)
    );

    sigmoid_lut sig_inst (
        .z_in(conv_result),
        .a_sigmoid(sigmoid_out)
    );

    // Multiplexer for final output
    assign pixel_out = (act_type == 2'd0) ? act_leaky :
                       (act_type == 2'd1) ? tanh_out  :
                       (act_type == 2'd2) ? sigmoid_out : conv_result;
    
    assign valid_out = conv_valid;

endmodule