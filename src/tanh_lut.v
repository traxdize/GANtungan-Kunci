// File         : tanh_lut.v
// Description  : Tanh LUT for Q16.16 format (32-bit)
//                Updated for higher precision (Step 2^-7)

module tanh_lut (
    input  signed [31:0] z_in,   // Q16.16
    output signed [31:0] a_tanh   // Q16.16
);

    // 1024 entries match the Python generator
    localparam ADDRESS_BITS = 10; 
    localparam DATA_WIDTH   = 32;
    localparam ROM_DEPTH    = 1 << ADDRESS_BITS;

    // Saturation outputs (Q16.16)
    localparam signed [31:0] MAX_POSITIVE_VAL = 32'h00010000; // +1.0
    localparam signed [31:0] MAX_NEGATIVE_VAL = 32'hFFFF0000; // -1.0

    // Clamp thresholds (-6.0 to +6.0 in Q16.16)
    // The LUT covers 0 to 8.0, so 6.0 is safely within range.
    localparam signed [31:0] CLAMP_POS = 32'h00060000;
    localparam signed [31:0] CLAMP_NEG = 32'hFFFA0000;

    reg [DATA_WIDTH-1:0] TANH_ROM [0:ROM_DEPTH-1];

    initial begin
        $readmemh("./mem/tanh_lut_mem.hex", TANH_ROM);
    end

    // Absolute value for symmetric LUT
    wire signed [31:0] z_abs = z_in[31] ? -z_in : z_in;

    // Address extraction:
    // Q16.16 format:
    // Bit 16 = 2^0 (1.0)
    // ...
    // Bit 9  = 2^-7 (0.0078125)
    //
    // Slice [18:9] gives 10 bits. 
    // Max index (all 1s) = 1023 -> 1023 * 2^-7 = ~7.99
    wire [ADDRESS_BITS-1:0] rom_address = z_abs[18:9];

    wire signed [31:0] rom_data = TANH_ROM[rom_address];

    // Final output: clamp + restore sign
    assign a_tanh =
        (z_in >= CLAMP_POS) ? MAX_POSITIVE_VAL :
        (z_in <= CLAMP_NEG) ? MAX_NEGATIVE_VAL :
        (z_in[31] ? -rom_data : rom_data);

endmodule