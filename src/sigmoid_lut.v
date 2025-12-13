// File: sigmoid_lut.v
// Description: Sigmoid Look-Up Table (LUT) implementation with robust clamping logic.
// Format: Q1.7.8 (16 bits total)
// Size: 1024 entries (10 address bits)

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
    // Load the fixed-point Sigmoid values from the .hex file
    $readmemh("sigmoid_lut_mem.hex", SIGMOID_ROM);
    $display("SIGMOID_ROM initialized successfully with %0d entries.", ROM_DEPTH);
end

// --- 2. Address Generation ---
// The address is derived from the middle 10 bits [14:5] of the input Z.
wire [ADDRESS_BITS-1:0] rom_address = z_q1_7_8[14:5];

// --- 3. Combined Clamping and ROM Read Operation ---
// Uses continuous assign for combinational logic.
assign a_sigmoid = 
    // Case 1: Extreme Positive Saturation (Z >= 6.0)
    // Sigmoid(Z) -> 1.0
    ($signed(z_q1_7_8) >= $signed(POS_CLAMP_THRESHOLD)) ? SIGMOID_MAX_VAL :
    
    // Case 2: Extreme Negative Saturation (Z <= -6.0)
    // Sigmoid(Z) -> 0.0  <-- CORRECTED CLAMP VALUE
    ($signed(z_q1_7_8) <= $signed(NEG_CLAMP_THRESHOLD)) ? SIGMOID_MIN_VAL :
    
    // Case 3: Within the Critical Range (-6.0 < Z < 6.0), use the LUT
    SIGMOID_ROM[rom_address];

endmodule