// File         : tanh_lut.v
// Description  : Tanh LUT for Q1.15.16 format (32-bit).

module tanh_lut (
    input  signed [31:0] z_in,   // Q16.16
    output signed [31:0] a_tanh  // Q16.16
);
    localparam ADDRESS_BITS = 10;
    localparam DATA_WIDTH   = 32;
    localparam ROM_DEPTH    = 1 << ADDRESS_BITS;

    // Output saturation values (Q16.16)
    localparam MAX_POSITIVE_VAL = 32'h00010000; // +1.0
    localparam MAX_NEGATIVE_VAL = 32'hFFFF0000; // -1.0

    // Clamp thresholds (+/-6.0 in Q16.16)
    localparam CLAMP_POS = 32'h00060000;
    localparam CLAMP_NEG = 32'hFFFA0000;

    reg [DATA_WIDTH-1:0] TANH_ROM [0:ROM_DEPTH-1];

    initial begin
        // ROM contents loaded from hex file
        $readmemh("mem/tanh_lut_mem.hex", TANH_ROM);
    end

    // Use absolute value for table lookup
    wire signed [31:0] z_abs = z_in[31] ? -z_in : z_in;

    // Address bits taken from fractional region (resolution ~0.125)
    wire [ADDRESS_BITS-1:0] rom_address = z_abs[18:9];
    wire signed [31:0] rom_data = TANH_ROM[rom_address];

    // Output with clamping and symmetry
    assign a_tanh =
        (z_in >= $signed(CLAMP_POS)) ? MAX_POSITIVE_VAL :
        (z_in <= $signed(CLAMP_NEG)) ? MAX_NEGATIVE_VAL :
        (z_in[31] ? -rom_data : rom_data);

endmodule