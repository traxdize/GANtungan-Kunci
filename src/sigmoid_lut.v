// File         : sigmoid_lut.v
// Description  : Sigmoid LUT for Q1.15.16 format (32-bit).

module sigmoid_lut (
    input  signed [31:0] z_in,   // Q16.16
    output signed [31:0] a_sigmoid // Q16.16
);
    localparam ADDRESS_BITS = 10;
    localparam DATA_WIDTH   = 32;
    localparam ROM_DEPTH    = 1 << ADDRESS_BITS;

    // Saturation values (Q16.16)
    localparam SIGMOID_MAX_VAL = 32'h00010000; // 1.0
    localparam SIGMOID_MIN_VAL = 32'h00000000; // 0.0

    // Clamp input magnitude at +/-6.0 (Q16.16)
    localparam POS_CLAMP_THRESHOLD = 32'h00060000; // +6.0
    localparam NEG_CLAMP_THRESHOLD = 32'hFFFA0000; // -6.0

    reg [DATA_WIDTH-1:0] SIGMOID_ROM [0:ROM_DEPTH-1];

    initial begin
        // ROM contents loaded from hex file
        $readmemh("mem/sigmoid_lut_mem.hex", SIGMOID_ROM);
    end

    // Use symmetry: compute abs(z) for lookup
    wire is_negative = z_in[31];
    wire signed [31:0] z_abs = is_negative ? -z_in : z_in;

    // Address bits selected from fractional range (resolution ~0.125)
    wire [ADDRESS_BITS-1:0] rom_address = z_abs[15:6];
    wire signed [31:0] rom_data = SIGMOID_ROM[rom_address];

    assign a_sigmoid =
        (z_in >= $signed(POS_CLAMP_THRESHOLD)) ? SIGMOID_MAX_VAL :
        (z_in <= $signed(NEG_CLAMP_THRESHOLD)) ? SIGMOID_MIN_VAL :
        (is_negative ? (SIGMOID_MAX_VAL - rom_data) : rom_data);

endmodule