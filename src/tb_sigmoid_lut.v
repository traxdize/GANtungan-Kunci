// File         : tb_sigmoid_lut.v
// Description  : Testbench for the Q16.16 sigmoid_lut module

`timescale 1ns / 1ps
`include "sigmoid_lut.v"

module tb_sigmoid_lut;

    // --- Signals ---
    reg  signed [31:0] z_in;
    wire signed [31:0] a_out;
    
    // --- Instantiate DUT ---
    sigmoid_lut DUT (
        .z_in (z_in),
        .a_sigmoid (a_out)
    );

    // --- Helper: Q16.16 to Float ---
    function real q2f;
        input [31:0] val;
        begin
            q2f = $signed(val) / 65536.0;
        end
    endfunction

    initial begin
        $dumpfile("wave/tb_sigmoid_lut.vcd");
        $dumpvars(0, tb_sigmoid_lut);
        
        $display("----------------------------------------------------------");
        $display(" Test |   Input (Float)  |   Output (Float)  | Expected");
        $display("----------------------------------------------------------");

        // 1. Zero Input -> 0.5
        z_in = 32'h00000000; #10;
        $display("    1 | %16.8f | %16.8f |    0.500", q2f(z_in), q2f(a_out));

        // 2. Positive Small (1.0) -> ~0.731
        z_in = 32'h00010000; #10;
        $display("    2 | %16.8f | %16.8f | ~  0.731", q2f(z_in), q2f(a_out));
        
        // 3. Negative Small (-1.0) -> ~0.268 (1 - 0.731)
        z_in = 32'hFFFF0000; #10;
        $display("    3 | %16.8f | %16.8f | ~  0.269", q2f(z_in), q2f(a_out));
        
        // 4. Test Precision Case (0.5) -> ~0.622
        // Old LUT would likely snap this to nearest 0.125
        z_in = 32'h00008000; #10;
        $display("    4 | %16.8f | %16.8f | ~  0.622", q2f(z_in), q2f(a_out));

        // 5. Saturation (> 6.0)
        z_in = 32'h00070000; #10;
        $display("    5 | %16.8f | %16.8f |    1.000", q2f(z_in), q2f(a_out));
        
        // 6. Negative Saturation (< -6.0)
        z_in = 32'hFFF90000; #10;
        $display("    6 | %16.8f | %16.8f |    0.000", q2f(z_in), q2f(a_out));

        $finish;
    end
endmodule