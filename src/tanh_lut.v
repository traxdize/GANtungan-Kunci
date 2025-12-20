// File: tanh_lut.v
// Description: Tanh LUT for Q1.15.16 format (32-bit).

module tanh_lut (
    input  signed [31:0] z_in,   // Input Q16.16
    output signed [31:0] a_tanh  // Output Q16.16
);
    localparam ADDRESS_BITS = 10;
    localparam DATA_WIDTH   = 32;
    localparam ROM_DEPTH    = 1 << ADDRESS_BITS;

    // Q16.16 Constants
    // 1.0 = 65536 (0x00010000)
    localparam MAX_POSITIVE_VAL = 32'h00010000;
    localparam MAX_NEGATIVE_VAL = 32'hFFFF0000; // -1.0
    
    // Clamping Thresholds (+/- 6.0)
    // 6.0 * 65536 = 393216 = 0x00060000
    localparam POS_CLAMP_THRESHOLD = 32'h00060000;
    localparam NEG_CLAMP_THRESHOLD = 32'hFFAA0000; // -6.0 (Two's comp roughly) 
    // Actually -6.0 in hex: ~0x00060000 + 1 = 0xFFFA0000
    // Let's use rigorous hex for -6.0:
    // 6.0 = 0x00060000. -6.0 = 0xFFFA0000.
    
    localparam CLAMP_POS = 32'h00060000;
    localparam CLAMP_NEG = 32'hFFFA0000; 

    reg [DATA_WIDTH-1:0] TANH_ROM [0:ROM_DEPTH-1];

    initial begin
        // Ensure you generated this file using the Python script provided
        $readmemh("mem/tanh_lut_mem.hex", TANH_ROM); 
    end

    // --- Address Generation ---
    // Q16.16 format: [31] Sign, [30:16] Integer, [15:0] Fraction.
    // Bit 16 is 2^0. Bit 13 is 2^-3 (0.125).
    // To match previous resolution logic, we look at the integer and high fraction bits.
    // We take the absolute value for addressing if the ROM is 0..Max.
    // However, Tanh is odd symmetric. We often read |z| and flip sign of output if z < 0.
    // Or, if the ROM contains data for positive inputs:
    
    wire signed [31:0] z_abs = (z_in[31]) ? -z_in : z_in;
    
    // Slice [22:13] gives us 10 bits.
    // Max index 1023 corresponds to 1023 * 0.125 = 127.8 (covers the 6.0 clamp range easily).
    wire [ADDRESS_BITS-1:0] rom_address = z_abs[22:13];
    
    wire signed [31:0] rom_data = TANH_ROM[rom_address];

    // --- Output Logic ---
    assign a_tanh = 
        (z_in >= $signed(CLAMP_POS)) ? MAX_POSITIVE_VAL :
        (z_in <= $signed(CLAMP_NEG)) ? MAX_NEGATIVE_VAL :
        // Symmetry: Tanh(-x) = -Tanh(x)
        (z_in[31] ? -rom_data : rom_data);

endmodule