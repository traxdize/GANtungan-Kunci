// Testbench for `tanh_lut` (Q8.24)
`timescale 1ns / 1ps

`include "tanh_lut.v"

module tb_tanh_lut;

    // Signals
    reg [31:0] z_in; // Q8.24
    wire [31:0] a_out; // Q8.24

    // DUT
    tanh_lut DUT (
        .z_in (z_in),
        .a_tanh   (a_out)
    );

    // --- Utility Function: Convert Q8.24 Fixed-Point to Float ---
    function real q_to_float;
        input [31:0] fixed_val;
        begin
            q_to_float = $signed(fixed_val) / 16777216.0; // 2^24
        end
    endfunction

    // (no separator task) use plain $display for headings

    initial begin
        // Logging
        $dumpfile("wave/tb_tanh_lut.vcd");
        $dumpvars(0, tb_tanh_lut);

        $display("");
        $display("TANH LUT Simulation (Q8.24)");
        $display("");

        // Tests
        test_case(1, 32'hFF80DED3);
        test_case(2, 32'h00000000);
        test_case(3, 32'h00800000);
        test_case(4, 32'h07000000);

        $finish;
    end

    // Task to apply stimulus and display results
    task test_case;
        input integer case_num;
        input [31:0] input_val;
        begin
            z_in = input_val;
            #10;
            $display("Test %0d: Input=%h (%0.8f) -> Output=%h (%0.8f)", case_num, z_in, q_to_float(z_in), a_out, q_to_float(a_out));
        end
    endtask

endmodule
