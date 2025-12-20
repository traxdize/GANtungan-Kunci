`timescale 1ns/1ps
`include "gan3x3.v"

module tb_gan3x3;

    // ============================================================
    // 1. Parameters & Signals
    // ============================================================
    parameter DATA_WIDTH = 32;
    // Helper to print float values from Q16.16
    real float_out; 

    // Inputs to DUT
    reg clk;
    reg rst;
    reg start;
    reg signed [DATA_WIDTH-1:0] noise_in1;
    reg signed [DATA_WIDTH-1:0] noise_in2;

    // Outputs from DUT
    wire signed [DATA_WIDTH-1:0] disc_out;
    wire done;

    // ============================================================
    // 2. Instantiate the Device Under Test (DUT)
    // ============================================================
    gan3x3 #(.DATA_WIDTH(DATA_WIDTH)) u_dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .noise_in1(noise_in1),
        .noise_in2(noise_in2),
        .disc_out(disc_out),
        .done(done)
    );

    // ============================================================
    // 3. Clock Generation (10ns Period = 100 MHz)
    // ============================================================
    always #5 clk = ~clk;

    // ============================================================
    // 4. Test Sequence
    // ============================================================
    initial begin
        // Initialize Inputs
        clk = 0;
        rst = 0; // Active Low Reset in your design? Check your rst logic.
                 // Your design uses "if (!rst)" which implies Active Low.
                 // So rst=0 is RESET, rst=1 is RUN.
        start = 0;
        noise_in1 = 0;
        noise_in2 = 0;

        // --------------------------------------------------------
        // Reset Sequence
        // --------------------------------------------------------
        $display("--- Simulation Start ---");
        #50;
        rst = 1; // Release Reset
        #20;

        // --------------------------------------------------------
        // Test Case 1: Run Inference with Noise A
        // --------------------------------------------------------
        $display("\n--- Test Case 1: Noise [0.5, -0.2] ---");
        
        // Input Noise: 0.5 and -0.2 in Q16.16 Fixed Point
        // 0.5 * 65536 = 32768 = 0x8000
        // -0.2 * 65536 = -13107.2 = 0xFFFFCCCD (Twos Comp)
        noise_in1 = 32'h0000_8000; 
        noise_in2 = 32'hFFFF_CCCD;
        
        // Pulse Start
        start = 1;
        #10; 
        start = 0;

        // Wait for completion
        wait(done);
        #10; // Wait a cycle to stabilize

        // --- Print Results ---
        // Convert Q16.16 to Real for readability in console
        float_out = $signed(disc_out) / 65536.0;
        
        $display("Done Signal Received!");
        $display("Discriminator Output (Raw Hex): %h", disc_out);
        $display("Discriminator Probability: %0.4f", float_out);

        // --- Debug: Peek into Internal RAM to see the Fake Image ---
        // Accessing u_dut.internal_ram[3] to [11] (The 9 output pixels)
        $display("Generated Fake Image (3x3):");
        $display("[ %h  %h  %h ]", u_dut.internal_ram[3], u_dut.internal_ram[4], u_dut.internal_ram[5]);
        $display("[ %h  %h  %h ]", u_dut.internal_ram[6], u_dut.internal_ram[7], u_dut.internal_ram[8]);
        $display("[ %h  %h  %h ]", u_dut.internal_ram[9], u_dut.internal_ram[10], u_dut.internal_ram[11]);


        // --------------------------------------------------------
        // Test Case 2: Run Inference with different Noise
        // --------------------------------------------------------
        #50;
        $display("\n--- Test Case 2: Noise [-1.0, 1.0] ---");
        
        // Noise: -1.0 and 1.0
        noise_in1 = 32'hFFFF_0000;
        noise_in2 = 32'h0001_0000;
        
        start = 1;
        #10;
        start = 0;
        
        wait(done); // Wait for done to go High again
        #10;

        float_out = $signed(disc_out) / 65536.0;
        $display("Discriminator Output (Raw Hex): %h", disc_out);
        $display("Discriminator Probability: %0.4f", float_out);
        float_out = $signed(disc_out) / 65536.0;
        $display("Discriminator Output (Raw Hex): %h", disc_out);
        $display("Discriminator Probability: %0.4f", float_out);

        // --- ADD THIS BLOCK TO SEE THE IMAGE FOR TEST CASE 2 ---
        $display("Generated Fake Image (3x3):");
        $display("[ %h  %h  %h ]", u_dut.internal_ram[3], u_dut.internal_ram[4], u_dut.internal_ram[5]);
        $display("[ %h  %h  %h ]", u_dut.internal_ram[6], u_dut.internal_ram[7], u_dut.internal_ram[8]);
        $display("[ %h  %h  %h ]", u_dut.internal_ram[9], u_dut.internal_ram[10], u_dut.internal_ram[11]);
        // -------------------------------------------------------
        // End Simulation
        #100;
        $display("\n--- Simulation Complete ---");
        $finish;
    end

    // Optional: Dump Waveforms for GTKWave / Vivado
    initial begin
        $dumpfile("gan_waveform.vcd");
        $dumpvars(0, tb_gan3x3);
    end

endmodule