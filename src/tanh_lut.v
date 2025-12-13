// File: tanh_lut.v
// Description: Tanh Look-Up Table (LUT) implementation with robust clamping logic.
// Format: Q1.7.8 (16 bits total)
// Size: 1024 entries (10 address bits)

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
// We sampled the LUT up to 5.0. To be safe, we check inputs >= 6.0 and <= -6.0.
// 6.0 in Q1.7.8: 5.0 * 256 = 1280 (16'h0500)
localparam POS_CLAMP_THRESHOLD = 16'h0500;
// -6.0 in Q1.7.8: -5.0 * 256 = -1280 (Two's Complement: 16'hFB00)
localparam NEG_CLAMP_THRESHOLD = 16'hFB00;

// Internal ROM array (1024 entries, 16 bits wide)
reg [DATA_WIDTH-1:0] TANH_ROM [0:ROM_DEPTH-1];

// --- 1. Memory Initialization ---
initial begin
    // Load the fixed-point Tanh values from the .hex file
    $readmemh("tanh_lut_mem.hex", TANH_ROM);
    $display("TANH_ROM initialized successfully with %0d entries.", ROM_DEPTH);
end

// --- 2. Address Generation ---
// The address is derived from the middle 10 bits [14:5] of the input Z.
wire [ADDRESS_BITS-1:0] rom_address = z_q1_7_8[14:5];

// --- 3. Combined Clamping and ROM Read Operation ---
// This uses a continuous assign for purely combinational logic (no clock needed for read).
// Note: $signed() casting is crucial for correct comparison in Verilog.
assign a_tanh = 
    // Case 1: Extreme Positive Saturation (Z >= 6.0)
    ($signed(z_q1_7_8) >= $signed(POS_CLAMP_THRESHOLD)) ? MAX_POSITIVE_VAL :
    
    // Case 2: Extreme Negative Saturation (Z <= -6.0)
    ($signed(z_q1_7_8) <= $signed(NEG_CLAMP_THRESHOLD)) ? MAX_NEGATIVE_VAL :
    
    // Case 3: Within the Critical Range (-6.0 < Z < 6.0), use the LUT
    TANH_ROM[rom_address];

endmodule