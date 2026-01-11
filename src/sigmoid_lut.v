// File         : sigmoid_lut.v
// Description  : Sigmoid lookup table for Parameterized Fixed Point

module sigmoid_lut #(
    parameter DATA_WIDTH = 32,
    parameter FRAC_WIDTH = 24
)(
    input  signed [DATA_WIDTH-1:0] z_in,
    output signed [DATA_WIDTH-1:0] a_sigmoid
);
    localparam ADDRESS_BITS = 10;
    localparam ROM_DEPTH    = 1 << ADDRESS_BITS;

    // Saturation limits
    localparam signed [DATA_WIDTH-1:0] SIGMOID_MAX_VAL = (1 <<< FRAC_WIDTH); // 1.0
    localparam signed [DATA_WIDTH-1:0] SIGMOID_MIN_VAL = {DATA_WIDTH{1'b0}}; // 0.0

    // Clamp thresholds (±6.0)
    localparam signed [DATA_WIDTH-1:0] POS_CLAMP_THRESHOLD = (6 <<< FRAC_WIDTH);
    localparam signed [DATA_WIDTH-1:0] NEG_CLAMP_THRESHOLD = -(6 <<< FRAC_WIDTH);

    reg [DATA_WIDTH-1:0] SIGMOID_ROM [0:ROM_DEPTH-1];

    // Load ROM
    initial begin
        $readmemh("./mem/sigmoid_lut_mem.hex", SIGMOID_ROM);
    end

    // Use symmetry: sigmoid(-x) = 1 - sigmoid(x)
    wire is_negative = z_in[DATA_WIDTH-1];
    wire signed [DATA_WIDTH-1:0] z_abs = is_negative ? -z_in : z_in;

    // Address bits Logic:
    // Matches the range logic of the Tanh LUT (Bits [FRAC+2 : FRAC-7])
    wire [ADDRESS_BITS-1:0] rom_address = z_abs[FRAC_WIDTH+2 : FRAC_WIDTH-7];
    wire signed [DATA_WIDTH-1:0] rom_data = SIGMOID_ROM[rom_address];

    assign a_sigmoid =
        (z_in >= POS_CLAMP_THRESHOLD) ? SIGMOID_MAX_VAL :
        (z_in <= NEG_CLAMP_THRESHOLD) ? SIGMOID_MIN_VAL :
        (is_negative ? (SIGMOID_MAX_VAL - rom_data) : rom_data);

endmodule