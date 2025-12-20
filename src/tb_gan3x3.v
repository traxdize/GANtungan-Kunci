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
        @(negedge clk); // Synchronize to Falling Edge
        rst = 1;        // Release Reset away from posedge
        
        // --------------------------------------------------------
        // Test Case 1: Noise [0.5, -0.2]
        // --------------------------------------------------------
        #20; 
        @(negedge clk); // DRIVE INPUTS ON FALLING EDGE
        $display("\n--- Test Case 1: Noise [0.5, -0.2] ---");
        
        noise_in1 = 32'h0000_8000; 
        noise_in2 = 32'hFFFF_CCCD;
        start = 1;
        
        @(negedge clk); // Hold for 1 cycle
        start = 0;

        wait(done);
        @(negedge clk); 

        // Print Results
        float_out = $signed(disc_out) / 65536.0;
        $display("Done Signal Received!");
        $display("Discriminator Output (Raw Hex): %h", disc_out);
        $display("Discriminator Probability: %0.4f", float_out);

        $display("Generated Fake Image (3x3):");
        $display("[ %h  %h  %h ]", u_dut.internal_ram[3], u_dut.internal_ram[4], u_dut.internal_ram[5]);
        $display("[ %h  %h  %h ]", u_dut.internal_ram[6], u_dut.internal_ram[7], u_dut.internal_ram[8]);
        $display("[ %h  %h  %h ]", u_dut.internal_ram[9], u_dut.internal_ram[10], u_dut.internal_ram[11]);

        // --------------------------------------------------------
        // Test Case 2: Noise [-1.0, 1.0]
        // --------------------------------------------------------
        #50;
        @(negedge clk); // DRIVE INPUTS ON FALLING EDGE
        $display("\n--- Test Case 2: Noise [-1.0, 1.0] ---");
        
        noise_in1 = 32'hFFFF_0000;
        noise_in2 = 32'h0001_0000;
        start = 1;
        
        @(negedge clk);
        start = 0;
        
        wait(done);
        @(negedge clk);

        float_out = $signed(disc_out) / 65536.0;
        $display("Discriminator Output (Raw Hex): %h", disc_out);
        $display("Discriminator Probability: %0.4f", float_out);
        
        $display("Generated Fake Image (3x3):");
        $display("[ %h  %h  %h ]", u_dut.internal_ram[3], u_dut.internal_ram[4], u_dut.internal_ram[5]);
        $display("[ %h  %h  %h ]", u_dut.internal_ram[6], u_dut.internal_ram[7], u_dut.internal_ram[8]);
        $display("[ %h  %h  %h ]", u_dut.internal_ram[9], u_dut.internal_ram[10], u_dut.internal_ram[11]);

        #100;
        $display("\n--- Simulation Complete ---");
        $finish;
    end

    // Optional: Dump Waveforms
    initial begin
        $dumpfile("gan_waveform.vcd");
        $dumpvars(0, tb_gan3x3);
    end

endmodule