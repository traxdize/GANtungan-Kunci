// File         : tb_tanh_lut.v
// Description  : Testbench for the tanh_lut module

`timescale 1ns / 1ps

`include "tanh_lut.v"

module tb_tanh_lut;

    // --- Signals for I/O ---
    reg [31:0] z_in;             // Input Z signal (Q16.16)
    wire [31:0] a_out;           // Output A_tanh signal (16.16)
    
    // --- Instantiate the DUT ---
    tanh_lut DUT (
        .z_in (z_in),
        .a_tanh   (a_out)
    );

    // --- Utility Function: Convert Q16.16 Fixed-Point to Float ---
    function real q_to_float;
        input [31:0] fixed_val;
        begin
            q_to_float = $signed(fixed_val) / 65536.0;
        end
    endfunction

    // --- Simulation Control and Test Vectors ---
    initial begin
        // Setup logging
        $dumpfile("wave/tb_tanh_lut.vcd");
        $dumpvars(0, tb_tanh_lut);
        
        $display("-----------------------------------------------------------------");
        $display("TANH LUT Simulation (Q16.16) Trace");
        $display("-----------------------------------------------------------------");
        $display(" Test | Z_Input(Q) | Z_Input(Float) | Addr | A_Output(Q) | A_Output(Float)");
        $display("-----------------------------------------------------------------");

        // 1. The specific failing case from Python
        // Input: -0.4966 -> Expect ~ -0.459
        test_case(1, 32'hFFFF80E1); 

        // 2. Zero
        test_case(2, 32'h00000000);

        // 3. Small Positive (0.5)
        test_case(3, 32'h00008000);
        
        // 4. Saturation Check (> 6.0)
        test_case(4, 32'h00070000);

        $display("-----------------------------------------------------------------");
        $finish;
    end

    // Task to apply stimulus and display results
    task test_case;
        input integer case_num;
        input [31:0] input_val;
        begin
            z_in = input_val;
            #10; 
            $display(" %4d | %h | %14.8f | ---- | %h | %14.8f", 
                case_num, 
                z_in, 
                q_to_float(z_in), 
                a_out, 
                q_to_float(a_out)
            );
        end
    endtask

endmodule