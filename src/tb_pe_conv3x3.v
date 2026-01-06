`timescale 1ns/1ps

`include "pe_conv3x3.v"

module tb_pe_conv3x3();
    reg clk;
    reg rst_n;
    reg en;
    reg signed [31:0] p [0:8];
    reg signed [31:0] w [0:8];
    reg signed [31:0] b;
    
    wire signed [31:0] result;
    wire valid_out;

    // Tolerance for fixed-point truncation (5 LSBs)
    localparam TOLERANCE = 32'h00000005;
    localparam EXPECTED  = 32'h00016666;

    pe_conv3x3 uut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .p0(p[0]), .p1(p[1]), .p2(p[2]), .p3(p[3]), .p4(p[4]), .p5(p[5]), .p6(p[6]), .p7(p[7]), .p8(p[8]),
        .w0(w[0]), .w1(w[1]), .w2(w[2]), .w3(w[3]), .w4(w[4]), .w5(w[5]), .w6(w[6]), .w7(w[7]), .w8(w[8]),
        .bias(b),
        .result(result),
        .valid_out(valid_out)
    );

    // Clock Generation
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // Reset and Initialization
        rst_n = 0;
        en = 0;
        b = 32'h00008000; // 0.5 in Q16.16
        
        // Setup inputs: Pixels = 0.1 (0x1999), Weights = 1.0 (0x10000)
        for(integer i=0; i<9; i=i+1) begin
            w[i] = 32'h00010000; // 1.0
            p[i] = 32'h00001999; // ~0.1
        end

        #20 rst_n = 1;
        #10 en = 1;
        
        // Monitor pipeline output
        wait(valid_out);
        #10;
        
        $display("--------------------------------------------------");
        $display("Hardware Output Result: %h", result);
        $display("Expected Result (Ideal): %h", EXPECTED);
        
        // Verification with tolerance check
        if ((result >= (EXPECTED - TOLERANCE)) && (result <= (EXPECTED + TOLERANCE))) begin
            $display("Status: PASS (Within fixed-point precision limits)");
        end else begin
            $display("Status: FAIL (Outside expected precision limits)");
        end
        $display("--------------------------------------------------");
        
        #50 $finish;
    end
endmodule