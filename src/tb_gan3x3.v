// File         : tb_gan3x3.v
// Description  : Testbench for the gan3x3 module

`timescale 1ns/1ps
`include "gan3x3.v"

module tb_gan3x3;

    parameter DATA_WIDTH = 32;
    real float_out; 

    reg clk;
    reg rst;
    reg start;
    reg signed [DATA_WIDTH-1:0] noise_in1;
    reg signed [DATA_WIDTH-1:0] noise_in2;

    wire signed [DATA_WIDTH-1:0] disc_out;
    wire done;

    gan3x3 #(.DATA_WIDTH(DATA_WIDTH)) u_dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .noise_in1(noise_in1),
        .noise_in2(noise_in2),
        .disc_out(disc_out),
        .done(done)
    );

    // Clock Generation
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 0;
        start = 0;
        noise_in1 = 0;
        noise_in2 = 0;

        $display("--- Simulation Start ---");

        // Reset Sequence
        #50;
        @(negedge clk);
        rst = 1; // Release Reset
        
        // --------------------------------------------------------
        // Test Case 1: Noise [0.5, -0.2]
        // --------------------------------------------------------
        #20;
        @(negedge clk);
        $display("\n--- Test Case 1: Noise [0.5, -0.2] ---");
        noise_in1 = 32'h0000_FFFF;  // 0.5
        noise_in2 = 32'hFFFF_CCCD;  // -0.2
        start = 1;
        
        @(negedge clk);
        start = 0;

        wait(done);
        @(negedge clk);

        // --- Print Results for Test Case 1 ---
        $display("Done Signal Received!");
        
        // 1. Generator Hidden Layer (G2) - stored in RAM [0..2]
        $display("\n[G2] Generator Hidden Layer Outputs:");
        $display("N1: %h", u_dut.internal_ram[0]);
        $display("N2: %h", u_dut.internal_ram[1]);
        $display("N3: %h", u_dut.internal_ram[2]);

        // 2. Generator Output Layer (G3) - stored in RAM [3..11]
        $display("\n[G3] Generated Fake Image (3x3):");
        $display("[ %h  %h  %h ]", u_dut.internal_ram[3], u_dut.internal_ram[4], u_dut.internal_ram[5]);
        $display("[ %h  %h  %h ]", u_dut.internal_ram[6], u_dut.internal_ram[7], u_dut.internal_ram[8]);
        $display("[ %h  %h  %h ]", u_dut.internal_ram[9], u_dut.internal_ram[10], u_dut.internal_ram[11]);

        // 3. Discriminator Hidden Layer (D2) - stored in RAM [12..14]
        $display("\n[D2] Discriminator Hidden Layer Outputs:");
        $display("N1: %h", u_dut.internal_ram[12]);
        $display("N2: %h", u_dut.internal_ram[13]);
        $display("N3: %h", u_dut.internal_ram[14]);

        // 4. Final Output
        float_out = $signed(disc_out) / 65536.0;
        $display("\n[D3] Discriminator Final Output:");
        $display("Raw Hex: %h", disc_out);
        $display("Probability: %0.4f", float_out);

        // --------------------------------------------------------
        // Test Case 2: Noise [-1.0, 1.0]
        // --------------------------------------------------------
        #50;
        @(negedge clk); 
        $display("\n--- Test Case 2: Noise [-1.0, 1.0] ---");
        noise_in1 = 32'hFFFF_0000; // -1.0
        noise_in2 = 32'h0001_0000; //  1.0
        start = 1;
        
        @(negedge clk);
        start = 0;
        
        wait(done);
        @(negedge clk);
        
        // --- Print Results for Test Case 2 ---
        
        // 1. Generator Hidden Layer (G2)
        $display("\n[G2] Generator Hidden Layer Outputs:");
        $display("N1: %h", u_dut.internal_ram[0]);
        $display("N2: %h", u_dut.internal_ram[1]);
        $display("N3: %h", u_dut.internal_ram[2]);
        
        // 2. Generator Output Layer (G3)
        $display("\n[G3] Generated Fake Image (3x3):");
        $display("[ %h  %h  %h ]", u_dut.internal_ram[3], u_dut.internal_ram[4], u_dut.internal_ram[5]);
        $display("[ %h  %h  %h ]", u_dut.internal_ram[6], u_dut.internal_ram[7], u_dut.internal_ram[8]);
        $display("[ %h  %h  %h ]", u_dut.internal_ram[9], u_dut.internal_ram[10], u_dut.internal_ram[11]);

        // 3. Discriminator Hidden Layer (D2)
        $display("\n[D2] Discriminator Hidden Layer Outputs:");
        $display("N1: %h", u_dut.internal_ram[12]);
        $display("N2: %h", u_dut.internal_ram[13]);
        $display("N3: %h", u_dut.internal_ram[14]);

        // 4. Final Output
        float_out = $signed(disc_out) / 65536.0;
        $display("\n[D3] Discriminator Final Output:");
        $display("Raw Hex: %h", disc_out);
        $display("Probability: %0.4f", float_out);

        #100;
        $display("\n--- Simulation Complete ---");
        $finish;
    end

    // Dump Waveforms
    initial begin
        $dumpfile("gan_waveform.vcd");
        $dumpvars(0, tb_gan3x3);
    end

endmodule