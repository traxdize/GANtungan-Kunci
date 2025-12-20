// File         : tb_tanh_lut.v
// Description  : Testbench for the tanh_lut module

`timescale 1ns / 1ps

// =========================================================================
// DEVICE UNDER TEST (DUT): tanh_lut
// Robust Tanh Look-Up Table (LUT) implementation with explicit clamping.
// Format: Q1.7.8 (16 bits total), Size: 1024 entries (10 address bits)
// NOTE: Requires 'tanh_lut_mem.hex' file in the same directory.
// =========================================================================

module tanh_lut (
    input  [15:0] z_q1_7_8,     // Input Z signal (16-bit scaled integer, Q1.7.8)
    output [15:0] a_tanh        // Output A_tanh (16-bit scaled integer, Q1.7.8)
);

// Configuration Parameters
localparam ADDRESS_BITS = 10;
localparam DATA_WIDTH   = 16;
localparam ROM_DEPTH    = 1 << ADDRESS_BITS; // 1024 entries

// Q1.7.8 fixed-point values for clamping:
// +1.0 * 256 = 256
localparam MAX_POSITIVE_VAL = 16'h0100;
// -1.0 * 256 = -256 (Two's Complement: 16'hFF00)
localparam MAX_NEGATIVE_VAL = 16'hFF00;

// Thresholds for Clamping Check:
// Check inputs >= 6.0 and <= -6.0.
// 6.0 in Q1.7.8: 6.0 * 256 = 1536 (16'h0600)
localparam POS_CLAMP_THRESHOLD = 16'h0600; 
// -6.0 in Q1.7.8: -6.0 * 256 = -1536 (Two's Complement: 16'hFA00)
localparam NEG_CLAMP_THRESHOLD = 16'hFA00; 

// Internal ROM array (1024 entries, 16 bits wide)
reg [DATA_WIDTH-1:0] TANH_ROM [0:ROM_DEPTH-1];

// --- 1. Memory Initialization ---
initial begin
    $readmemh("mem/tanh_lut_mem.hex", TANH_ROM);
    $display("TANH_ROM initialized successfully with %0d entries.", ROM_DEPTH);
end

// --- 2. Address Generation ---
// The address is derived from the middle 10 bits [14:5] of the input Z.
wire [ADDRESS_BITS-1:0] rom_address = z_q1_7_8[14:5];

// --- 3. Combined Clamping and ROM Read Operation ---
// Uses continuous assign for combinational logic.
assign a_tanh = 
    // Case 1: Extreme Positive Saturation (Z >= 6.0)
    ($signed(z_q1_7_8) >= $signed(POS_CLAMP_THRESHOLD)) ? MAX_POSITIVE_VAL :
    
    // Case 2: Extreme Negative Saturation (Z <= -6.0)
    ($signed(z_q1_7_8) <= $signed(NEG_CLAMP_THRESHOLD)) ? MAX_NEGATIVE_VAL :
    
    // Case 3: Within the Critical Range, use the LUT
    TANH_ROM[rom_address];

endmodule

// =========================================================================
// TESTBENCH (TB)
// Applies multiple test vectors to the tanh_lut module.
// =========================================================================

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
    function real q_to_float;
        input [15:0] fixed_val;
        begin
            q_to_float = $signed(fixed_val) / 256.0;
        end
    endfunction

    // --- Simulation Control and Test Vectors ---
    initial begin
        // Setup logging
        $dumpfile("wave/tb_tanh_lut.vcd");
        $dumpvars(0, tb_tanh_lut);
        
        $display("-----------------------------------------------------------------");
        $display("TANH LUT Simulation (Q1.7.8) Trace");
        $display("-----------------------------------------------------------------");
        $display(" Test | Z_Input(Q) | Z_Input(Float) | Addr | A_Output(Q) | A_Output(Float)");
        $display("-----------------------------------------------------------------");

        // --- Test Vectors (Q1.7.8 Scaled Integers) ---
        
        // 1. Zero Input (Z=0.0) -> Tanh(0)=0.0
        test_case(1, 16'h0000); 

        // 2. Positive Small (Z=0.5) -> Tanh ~0.46
        // 0.5 * 256 = 128
        test_case(2, 16'h0080);
        
        // 3. Negative Small (Z=-0.5) -> Tanh ~-0.46
        // -0.5 * 256 = -128
        test_case(3, 16'hFF80); 
        
        // 4. Positive Edge of Sampled Range (Z ~5.0) -> Tanh ~1.0
        // 5.0 * 256 = 1280. Using 1279 (16'h04FF) to be just inside the range.
        test_case(4, 16'h04FF);

        // 5. Negative Edge of Sampled Range (Z ~-5.0) -> Tanh ~-1.0
        // -5.0 * 256 = -1280. Using -1279 (16'hFB01) to be just inside the range.
        test_case(5, 16'hFB01);

        // 6. Positive Clamped Input (Z=10.0) -> Should clamp to +1.0 (16'h0100)
        // 10.0 * 256 = 2560 (16'h0A00)
        test_case(6, 16'h0A00); 

        // 7. Negative Clamped Input (Z=-10.0) -> Should clamp to -1.0 (16'hFF00)
        // -10.0 * 256 = -2560 (16'hF600)
        test_case(7, 16'hF600); 
        
        // 8. Test maximum hardware range (Z=127.996) -> Should clamp to +1.0
        // 16'h7FFF
        test_case(8, 16'h7FFF);
        
        // 9. Test minimum hardware range (Z=-128.0) -> Should clamp to -1.0
        // 16'h8000
        test_case(9, 16'h8000);

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