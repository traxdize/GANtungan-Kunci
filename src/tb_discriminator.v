// File: tb_discriminator.v
`timescale 1ns/1ps

`include "discriminator_3x3.v"

module tb_discriminator;
    parameter DATA_WIDTH = 32;

    reg clk;
    reg rst;
    reg start;

    // 9 Pixel Inputs
    reg signed [DATA_WIDTH-1:0] p1, p2, p3;
    reg signed [DATA_WIDTH-1:0] p4, p5, p6;
    reg signed [DATA_WIDTH-1:0] p7, p8, p9;

    wire signed [DATA_WIDTH-1:0] disc_out;
    wire done;

    real float_prob;

    // Instantiate DUT
    discriminator_3x3 #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .p1(p1), .p2(p2), .p3(p3),
        .p4(p4), .p5(p5), .p6(p6),
        .p7(p7), .p8(p8), .p9(p9),
        .disc_out(disc_out),
        .done(done)
    );

    // Clock Generation
    always #5 clk = ~clk;

    initial begin
        // Init
        clk = 0;
        rst = 1;
        start = 0;
        p1=0; p2=0; p3=0;
        p4=0; p5=0; p6=0;
        p7=0; p8=0; p9=0;

        $display("--- Isolated Discriminator Simulation ---");
        
        // Reset
        #50;
        @(negedge clk);
        rst = 0;

        // Apply Input Data (From Prompt)
        // Row 1
        p1 = 32'h00010000; p2 = 32'hffff0000; p3 = 32'h00010000;
        // Row 2
        p4 = 32'h0000ffff; p5 = 32'hffff0000; p6 = 32'h00010000;
        // Row 3
        p7 = 32'h0000ffff; p8 = 32'hffff0000; p9 = 32'h00010000;

        // Start Processing
        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        // Wait for completion
        wait(done);
        @(negedge clk);

        // Calculate Probability (Fixed Point 16.16 conversion)
        float_prob = $signed(disc_out) / 65536.0;

        // Display Results
        $display("\n[Input Image]");
        $display("[ %h  %h  %h ]", p1, p2, p3);
        $display("[ %h  %h  %h ]", p4, p5, p6);
        $display("[ %h  %h  %h ]", p7, p8, p9);

        $display("\n[Discriminator Output]");
        $display("Raw Hex: %h", disc_out);
        $display("Probability: %0.4f", float_prob);

        $finish;
    end

    // Waveform Dump
    initial begin
        $dumpfile("discriminator_isolated.vcd");
        $dumpvars(0, tb_discriminator);
    end

endmodule