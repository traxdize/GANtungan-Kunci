// File         : tb_gan3x3.v
// Description  : Testbench for the gan3x3 module (Parameterized)

`timescale 1ns/1ps
`include "gan3x3.v"

module tb_gan3x3;

    // Define format parameters here
    parameter DATA_WIDTH = 32;
    parameter FRAC_WIDTH = 28; // Change this to 16, 28, etc.

    real float_out; 
    reg clk;
    reg rst;
    reg start;
    reg signed [DATA_WIDTH-1:0] noise_in1;
    reg signed [DATA_WIDTH-1:0] noise_in2;

    wire signed [DATA_WIDTH-1:0] disc_out;
    wire done;

    gan3x3 #(
        .DATA_WIDTH(DATA_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) u_dut (
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
    
    // Helper: Fixed Point to Real
    function real fixed_to_real;
        input signed [DATA_WIDTH-1:0] val;
        begin
            fixed_to_real = $signed(val) / (2.0 ** FRAC_WIDTH);
        end
    endfunction

    // Helper: Real to Fixed Point
    function signed [DATA_WIDTH-1:0] real_to_fixed;
        input real val;
        begin
            real_to_fixed = $rtoi(val * (2.0 ** FRAC_WIDTH));
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

        $display("Simulation start. Format Q%0d.%0d", DATA_WIDTH-FRAC_WIDTH, FRAC_WIDTH);

        // Reset
        #20; @(negedge clk); rst = 1;

        // Test case: noise [0.5, -0.2]
        #20; @(negedge clk);
        $display("Test case: noise [0.5, -0.2]");
        
        // Generate inputs dynamically using the parameter
        noise_in1 = real_to_fixed(0.5);
        noise_in2 = real_to_fixed(-0.2);
        
        start = 1;
        
        #10;
        @(negedge clk);
        start = 0;

        wait(done);
        @(negedge clk);

        $display("");
        $display("RESULTS");
        $display("");

        // G2: generator hidden (RAM 0..2)
        $display("G2:");
        for (i = 0; i < 3; i = i + 1) begin
            $display("N%0d: %h (%0.6f)", i+1, u_dut.internal_ram[i], fixed_to_real(u_dut.internal_ram[i]));
        end

        // G3: generated image (float)
        $display("");
        $display("G3: image (float)");
        $display("");
        for (r = 0; r < 3; r = r + 1) begin
            idx = 3 + r*3;
            $display("%0.6f %0.6f %0.6f",
                fixed_to_real(u_dut.internal_ram[idx]),
                fixed_to_real(u_dut.internal_ram[idx+1]),
                fixed_to_real(u_dut.internal_ram[idx+2])
            );
        end

        // G3: generated image (raw)
        $display("");
        $display("G3: image (raw)");
        $display("");
        for (r = 0; r < 3; r = r + 1) begin
            idx = 3 + r*3;
            $display("%h %h %h",
                u_dut.internal_ram[idx],
                u_dut.internal_ram[idx+1],
                u_dut.internal_ram[idx+2]
            );
        end

        // D2: discriminator hidden (RAM 12..14)
        $display("");
        $display("D2: hidden");
        $display("");
        for (i = 0; i < 3; i = i + 1) begin
            $display("N%0d: %h (%0.6f)", i+1, u_dut.internal_ram[12 + i], fixed_to_real(u_dut.internal_ram[12 + i]));
        end

        // D3: final output
        float_out = fixed_to_real(disc_out);
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