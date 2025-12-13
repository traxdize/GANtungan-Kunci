// File: tb_tanh_lut.v
// Description: Testbench for the tanh_lut module.

`timescale 1ns / 1ps

module tb_tanh_lut;

    // --- Signals for I/O ---
    reg [15:0] z_in;             // Input Z signal (Q1.7.8)
    wire [15:0] a_out;            // Output A_tanh signal (Q1.7.8)
    
    // --- Instantiate the DUT ---
    tanh_lut DUT (
        .z_q1_7_8 (z_in),
        .a_tanh   (a_out)
    );

    // --- Utility Function: Convert Q1.7.8 Fixed-Point to Float ---
    // (For display purposes only - Icarus Verilog may not support complex $itor)
    function real q_to_float;
        input [15:0] fixed_val;
        begin
            // 2^8 = 256
            q_to_float = $signed(fixed_val) / 256.0;
        end
    endfunction

    // --- Simulation Control and Display ---
    initial begin
        // Open output file for logging
        $dumpfile("tb_tanh_lut.vcd");
        $dumpvars(0, tb_tanh_lut);
        
        $display("-----------------------------------------------------------------");
        $display("TANH LUT Simulation (Q1.7.8)");
        $display("Input_Z (Q1.7.8) | Input_Z (Float) | Address (Bits 14:5) | Output_A (Float)");
        $display("-----------------------------------------------------------------");

        // --- Test Cases ---
        
        // 1. Zero Input (Z=0.0) -> Tanh(0)=0.0
        z_in = 16'h0000;
        #10 $display("%h (%f) | %d | %f", z_in, q_to_float(z_in), z_in[14:5], q_to_float(a_out));

        // 2. Positive Small Input (Z=0.5 -> 0.462)
        // 0.5 * 256 = 128 (16'h0080)
        z_in = 16'h0080; 
        #10 $display("%h (%f) | %d | %f", z_in, q_to_float(z_in), z_in[14:5], q_to_float(a_out));
        
        // 3. Negative Small Input (Z=-0.5 -> -0.462)
        // -0.5 * 256 = -128 (16'hFF80)
        z_in = 16'hFF80; 
        #10 $display("%h (%f) | %d | %f", z_in, q_to_float(z_in), z_in[14:5], q_to_float(a_out));
        
        // 4. Positive Saturation Input (Z=4.0 -> Tanh ~1.0)
        // 4.0 * 256 = 1024 (16'h0400)
        z_in = 16'h0400; 
        #10 $display("%h (%f) | %d | %f", z_in, q_to_float(z_in), z_in[14:5], q_to_float(a_out));
        
        // 5. Negative Saturation Input (Z=-4.0 -> Tanh ~-1.0)
        // -4.0 * 256 = -1024 (16'hFC00)
        z_in = 16'hFC00; 
        #10 $display("%h (%f) | %d | %f", z_in, q_to_float(z_in), z_in[14:5], q_to_float(a_out));
        
        // 6. Maximum Positive Value (Z=127.996)
        // Max Q1.7.8 positive value is 2^15-1 = 32767 (16'h7FFF)
        z_in = 16'h7FFF;
        #10 $display("%h (%f) | %d | %f", z_in, q_to_float(z_in), z_in[14:5], q_to_float(a_out));

        $display("-----------------------------------------------------------------");
        $finish;
    end

endmodule
