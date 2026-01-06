`timescale 1ns/1ps

`include "compute_core.v"

module tb_compute_core();
    reg clk;
    reg rst_n;
    reg en;
    reg [5:0] img_width;
    reg [1:0] act_type;
    reg signed [31:0] slope;
    reg signed [31:0] pixel_in;
    reg valid_in;
    reg signed [31:0] w [0:8];
    reg signed [31:0] b;

    wire signed [31:0] pixel_out;
    wire valid_out;

    compute_core uut (
        .clk(clk), .rst_n(rst_n), .en(en),
        .img_width(img_width),
        .act_type(act_type),
        .slope(slope),
        .pixel_in(pixel_in),
        .valid_in(valid_in),
        .w0(w[0]), .w1(w[1]), .w2(w[2]), .w3(w[3]), .w4(w[4]), .w5(w[5]), .w6(w[6]), .w7(w[7]), .w8(w[8]),
        .bias(b),
        .pixel_out(pixel_out),
        .valid_out(valid_out)
    );

    always #5 clk = ~clk;

    integer i;

    initial begin
        clk = 0; rst_n = 0; en = 0;
        img_width = 6'd8;
        act_type = 2'd0;       // LeakyReLU/PReLU
        slope = 32'h00003333;  // 0.2 in Q16.16
        b = 32'h00000000;
        for(i=0; i<9; i=i+1) w[i] = 32'h00010000; // Unity weights

        #20 rst_n = 1;
        #10 en = 1;

        // Feed an 8x8 block of pixels
        for (i = 1; i <= 64; i = i + 1) begin
            @(posedge clk);
            pixel_in = i << 16; // Integer i in Q16.16
            valid_in = 1'b1;
        end

        @(posedge clk);
        valid_in = 1'b0;

        #200 $finish;
    end

    always @(posedge clk) begin
        if (valid_out)
            $display("Time: %0t | Core Output: %f", $time, pixel_out / 65536.0);
    end

endmodule