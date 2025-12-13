// File: sigmoid_testbench.v
// Description: Combines the robust sigmoid_lut module and its testbench for single-file simulation.

`timescale 1ns / 1ps

// =========================================================================
// DEVICE UNDER TEST (DUT): sigmoid_lut
// Robust Sigmoid Look-Up Table (LUT) implementation with explicit clamping.
// Format: Q1.7.8 (16 bits total), Size: 1024 entries (10 address bits)
// NOTE: Requires 'sigmoid_lut_mem.hex' file in the same directory.
// =========================================================================

module sigmoid_lut (
    input  [15:0] z_q1_7_8,     // Input Z signal (16-bit scaled integer, Q1.7.8)
    output [15:0] a_sigmoid     // Output A_sigmoid (16-bit scaled integer, Q1.7.8)
);

// Configuration Parameters
localparam ADDRESS_BITS = 10;
localparam DATA_WIDTH   = 16;
localparam ROM_DEPTH    = 1 << ADDRESS_BITS; // 1024 entries

// Q1.7.8 fixed-point values for clamping:
// Sigmoid output max is 1.0, min is 0.0.
localparam SIGMOID_MAX_VAL   = 16'h0100; // +1.0 * 256 = 256
localparam SIGMOID_MIN_VAL   = 16'h0000; // +0.0 * 256 = 0

// Thresholds for Clamping Check (Range: [-6.0, 6.0]):
// 6.0 in Q1.7.8: 16'h0600
localparam POS_CLAMP_THRESHOLD = 16'h0600; 
// -6.0 in Q1.7.8: 16'hFA00
localparam NEG_CLAMP_THRESHOLD = 16'hFA00; 

// Internal ROM array (1024 entries, 16 bits wide)
reg [DATA_WIDTH-1:0] SIGMOID_ROM [0:ROM_DEPTH-1];

// --- 1. Memory Initialization ---
initial begin
    $readmemh("sigmoid_lut_mem.hex", SIGMOID_ROM);
    $display("SIGMOID_ROM initialized successfully with %0d entries.", ROM_DEPTH);
end

// --- 2. Address Generation ---
// The address is derived from the middle 10 bits [14:5] of the input Z.
wire [ADDRESS_BITS-1:0] rom_address = z_q1_7_8[14:5];

// --- 3. Combined Clamping and ROM Read Operation ---
// Uses continuous assign for combinational logic.
assign a_sigmoid = 
    // Case 1: Extreme Positive Saturation (Z >= 6.0) -> Output 1.0
    ($signed(z_q1_7_8) >= $signed(POS_CLAMP_THRESHOLD)) ? SIGMOID_MAX_VAL :
    
    // Case 2: Extreme Negative Saturation (Z <= -6.0) -> Output 0.0
    ($signed(z_q1_7_8) <= $signed(NEG_CLAMP_THRESHOLD)) ? SIGMOID_MIN_VAL :
    
    // Case 3: Within the Critical Range, use the LUT
    SIGMOID_ROM[rom_address];

endmodule

// =========================================================================
// TESTBENCH (TB)
// Applies multiple test vectors to the sigmoid_lut module.
// =========================================================================

module tb_sigmoid_lut;

    // --- Signals for I/O ---
    reg [15:0] z_in;             // Input Z signal (Q1.7.8)
    wire [15:0] a_out;            // Output A_sigmoid signal (Q1.7.8)
    
    // --- Instantiate the DUT ---
    sigmoid_lut DUT (
        .z_q1_7_8 (z_in),
        .a_sigmoid (a_out)
    );

    // --- Utility Function: Convert Q1.7.8 Fixed-Point to Float ---
    function real q_to_float;
        input [15:0] fixed_val;
        begin
            q_to_float = $signed(fixed_val) / 256.0;
        end
    endfunction

    // --- Simulation Control and Test Vectors ---
    initial begin
        // Setup logging
        $dumpfile("tb_sigmoid_lut.vcd");
        $dumpvars(0, tb_sigmoid_lut);
        
        $display("-----------------------------------------------------------------");
        $display("SIGMOID LUT Simulation (Q1.7.8) Trace");
        $display("-----------------------------------------------------------------");
        $display(" Test | Z_Input(Q) | Z_Input(Float) | Addr | A_Output(Q) | A_Output(Float)");
        $display("-----------------------------------------------------------------");

        // --- Test Vectors (Q1.7.8 Scaled Integers) ---
        
        // 1. Zero Input (Z=0.0) -> Sigmoid(0)=0.5
        // 0.5 * 256 = 128 (16'h0080)
        test_case(1, 16'h0000); 

        // 2. Positive Small (Z=1.0) -> Sigmoid ~0.73
        // 1.0 * 256 = 256 (16'h0100)
        test_case(2, 16'h0100);
        
        // 3. Negative Small (Z=-1.0) -> Sigmoid ~0.27
        // -1.0 * 256 = -256 (16'hFF00)
        test_case(3, 16'hFF00); 
        
        // 4. Positive Saturation Edge (Z ~6.0) -> Should be near 1.0
        // 5.99 * 256 = 1533 (16'h05FD)
        test_case(4, 16'h05FD);

        // 5. Negative Saturation Edge (Z ~-6.0) -> Should be near 0.0
        // -5.99 * 256 = -1533 (16'hFA03)
        test_case(5, 16'hFA03);

        // 6. Positive Clamped Input (Z=10.0) -> Should clamp to +1.0 (16'h0100)
        // 10.0 * 256 = 2560 (16'h0A00)
        test_case(6, 16'h0A00); 

        // 7. Negative Clamped Input (Z=-10.0) -> Should clamp to 0.0 (16'h0000)
        // -10.0 * 256 = -2560 (16'hF600)
        test_case(7, 16'hF600); 
        
        // 8. Test maximum hardware range (Z=127.996) -> Should clamp to +1.0
        // 16'h7FFF
        test_case(8, 16'h7FFF);
        
        // 9. Test large negative value (Z=-30.0) -> Should clamp to 0.0
        // -30.0 * 256 = -7680 (16'hE200)
        test_case(9, 16'hE200);

        $display("-----------------------------------------------------------------");
        $finish;
    end

    // Task to apply stimulus and display results
    task test_case;
        input integer case_num;
        input [15:0] input_val;
        begin
            z_in = input_val;
            #10; // Allow time for combinational logic to propagate
            $display(" %4d | %h | %14.8f | %4d | %h | %14.8f", 
                case_num, 
                z_in, 
                q_to_float(z_in), 
                z_in[14:5], 
                a_out, 
                q_to_float(a_out)
            );
        end
    endtask

endmodule