// Testbench for `sigmoid_lut` (Q8.24)
`timescale 1ns / 1ps
`include "sigmoid_lut.v"

module tb_sigmoid_lut;

    // Signals
    reg  signed [31:0] z_in;
    wire signed [31:0] a_out;

    // DUT
    sigmoid_lut DUT (
        .z_in (z_in),
        .a_sigmoid (a_out)
    );

    // --- Helper: Q8.24 to Float ---
    function real q2f;
        input [31:0] val;
        begin
            q2f = $signed(val) / 16777216.0; // 2^24
        end
    endfunction

    initial begin
        $dumpfile("wave/tb_sigmoid_lut.vcd");
        $dumpvars(0, tb_sigmoid_lut);

        $display("");
        $display("SIGMOID LUT Simulation (Q8.24)");
        $display("");

        // Tests
        z_in = 32'h00000000; #10; $display("Test 1: Input=%h (%0.8f) -> Output=%h (%0.8f)", z_in, q2f(z_in), a_out, q2f(a_out));
        z_in = 32'h01000000; #10; $display("Test 2: Input=%h (%0.8f) -> Output=%h (%0.8f)", z_in, q2f(z_in), a_out, q2f(a_out));
        z_in = 32'hFF000000; #10; $display("Test 3: Input=%h (%0.8f) -> Output=%h (%0.8f)", z_in, q2f(z_in), a_out, q2f(a_out));
        z_in = 32'h00800000; #10; $display("Test 4: Input=%h (%0.8f) -> Output=%h (%0.8f)", z_in, q2f(z_in), a_out, q2f(a_out));
        z_in = 32'h07000000; #10; $display("Test 5: Input=%h (%0.8f) -> Output=%h (%0.8f)", z_in, q2f(z_in), a_out, q2f(a_out));
        z_in = 32'hF9000000; #10; $display("Test 6: Input=%h (%0.8f) -> Output=%h (%0.8f)", z_in, q2f(z_in), a_out, q2f(a_out));

        $finish;
    end
endmodule
