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

    // Clock
    always #5 clk = ~clk;
    
    // Helper: Q8.24 to real
    function real q8_24_to_real;
        input signed [31:0] val;
        begin
            q8_24_to_real = $signed(val) / 16777216.0; // 2^24
        end
    endfunction

    integer i, r, c, idx;


    // Waveform Dump
    initial begin
        $dumpfile("gan_3x3.vcd");
        $dumpvars(0, tb_gan3x3);
    end

    initial begin
        clk = 0;
        rst = 0;
        start = 0;
        noise_in1 = 0;
        noise_in2 = 0;

        $display("Simulation start");

        // Reset
        #20; @(negedge clk); rst = 1;

        // Test case: noise [0.5, -0.2]
        #20; @(negedge clk);
        $display("Test case: noise [0.5, -0.2]");
        noise_in1 = 32'h0080_0000;  // 0.5  -> 0.5 * 2^24 = 0x00800000
        noise_in2 = 32'hFFCC_CCCD;  // -0.2 -> -0.2 * 2^24 = 0xFFCCCCCD
        start = 1;
        
        #10;
        @(negedge clk);
        start = 0;

        wait(done);
        @(negedge clk);

        $display("");
        $display("RESULTS (Q8.24)");
        $display("");

        // G2: generator hidden (RAM 0..2)
        $display("G2:");
        for (i = 0; i < 3; i = i + 1) begin
            $display("N%0d: %h (%0.6f)", i+1, u_dut.internal_ram[i], q8_24_to_real(u_dut.internal_ram[i]));
        end

        // G3: generated image (float)
        $display("");
        $display("G3: image (float)");
        $display("");
        for (r = 0; r < 3; r = r + 1) begin
            idx = 3 + r*3;
            $display("%0.6f %0.6f %0.6f",
                q8_24_to_real(u_dut.internal_ram[idx]),
                q8_24_to_real(u_dut.internal_ram[idx+1]),
                q8_24_to_real(u_dut.internal_ram[idx+2])
            );
        end
        $display("");
        $display("G3: image (hex)");
        $display("");
        for (r = 0; r < 3; r = r + 1) begin
            idx = 3 + r*3;
            $display("%h %h %h",
                u_dut.internal_ram[idx], u_dut.internal_ram[idx+1], u_dut.internal_ram[idx+2]
            );
        end
        // D2: discriminator hidden (RAM 12..14)
        $display("");
        $display("D2: hidden");
        $display("");
        for (i = 0; i < 3; i = i + 1) begin
            $display("N%0d: %h (%0.6f)", i+1, u_dut.internal_ram[12 + i], q8_24_to_real(u_dut.internal_ram[12 + i]));
        end

        // D3: final output
        float_out = q8_24_to_real(disc_out);
        $display("");
        $display("D3: final");
        $display("");
        $display("Raw: %h", disc_out);
        $display("Prob: %0.6f", float_out);

        #100;
        $display("\n--- Simulation Complete ---");
        $finish;
    end

endmodule