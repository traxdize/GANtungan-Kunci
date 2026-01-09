// File         : tanh_lut.v
// Description  : Tanh LUT for Q8.24 format

module tanh_lut (
    input  signed [31:0] z_in,   // Q8.24
    output signed [31:0] a_tanh  // Q8.24
);
    localparam ADDRESS_BITS = 10; 
    localparam DATA_WIDTH   = 32;
    localparam ROM_DEPTH    = 1 << ADDRESS_BITS;

    // Saturation limits (Q8.24)
    localparam signed [31:0] MAX_POSITIVE_VAL = 32'h01000000; // +1.0
    localparam signed [31:0] MAX_NEGATIVE_VAL = 32'hFF000000; // -1.0

    // Clamp thresholds (±6.0 Q8.24)
    localparam signed [31:0] CLAMP_POS = 32'h06000000; // +6.0
    localparam signed [31:0] CLAMP_NEG = 32'hFA000000; // -6.0

    reg [DATA_WIDTH-1:0] TANH_ROM [0:ROM_DEPTH-1];

    // Load ROM from hex
    initial begin
        $readmemh("./mem/tanh_lut_mem.hex", TANH_ROM);
    end
    // Use absolute value (symmetric LUT)
    wire signed [31:0] z_abs = z_in[31] ? -z_in : z_in;

    // Address: take bits [26:17] to index LUT (step = 2^-7)
    wire [ADDRESS_BITS-1:0] rom_address = z_abs[26:17];
    wire signed [31:0] rom_data = TANH_ROM[rom_address];

    // Output: clamp then apply sign
    assign a_tanh =
        (z_in >= CLAMP_POS) ? MAX_POSITIVE_VAL :
        (z_in <= CLAMP_NEG) ? MAX_NEGATIVE_VAL :
        (z_in[31] ? -rom_data : rom_data);

endmodule