// sigmoid_lut: Sigmoid lookup table (Q8.24)
module sigmoid_lut (
    input  signed [31:0] z_in,   // Q8.24
    output signed [31:0] a_sigmoid // Q8.24
);
    localparam ADDRESS_BITS = 10;
    localparam DATA_WIDTH   = 32;
    localparam ROM_DEPTH    = 1 << ADDRESS_BITS;

    // Saturation limits (Q8.24)
    localparam signed [31:0] SIGMOID_MAX_VAL = 32'h01000000; // 1.0 (Q8.24)
    localparam signed [31:0] SIGMOID_MIN_VAL = 32'h00000000; // 0.0

    // Clamp thresholds (±6.0 Q8.24)
    localparam signed [31:0] POS_CLAMP_THRESHOLD = 32'h06000000; // +6.0
    localparam signed [31:0] NEG_CLAMP_THRESHOLD = 32'hFA000000; // -6.0 (two's complement)

    reg [DATA_WIDTH-1:0] SIGMOID_ROM [0:ROM_DEPTH-1];

    // Load ROM
    initial begin
        $readmemh("./mem/sigmoid_lut_mem.hex", SIGMOID_ROM);
    end

    // Use symmetry: sigmoid(-x) = 1 - sigmoid(x)
    wire is_negative = z_in[31];
    wire signed [31:0] z_abs = is_negative ? -z_in : z_in;

    // Address bits [26:17] index ROM (step = 2^-7)
    wire [ADDRESS_BITS-1:0] rom_address = z_abs[26:17];
    wire signed [31:0] rom_data = SIGMOID_ROM[rom_address];

    assign a_sigmoid =
        (z_in >= POS_CLAMP_THRESHOLD) ? SIGMOID_MAX_VAL :
        (z_in <= NEG_CLAMP_THRESHOLD) ? SIGMOID_MIN_VAL :
        (is_negative ? (SIGMOID_MAX_VAL - rom_data) : rom_data);

endmodule
