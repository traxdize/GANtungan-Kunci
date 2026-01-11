// File         : tanh_lut.v
// Description  : Tanh LUT for Parameterized Fixed Point

module tanh_lut #(
    parameter DATA_WIDTH = 32,
    parameter FRAC_WIDTH = 24
)(
    input  signed [DATA_WIDTH-1:0] z_in,
    output signed [DATA_WIDTH-1:0] a_tanh
);
    localparam ADDRESS_BITS = 10; 
    localparam ROM_DEPTH    = 1 << ADDRESS_BITS;

    // Saturation limits calculated dynamically
    // 1.0 represented as 1 shifted by FRAC_WIDTH
    localparam signed [DATA_WIDTH-1:0] MAX_POSITIVE_VAL = (1 <<< FRAC_WIDTH); 
    localparam signed [DATA_WIDTH-1:0] MAX_NEGATIVE_VAL = -(1 <<< FRAC_WIDTH);

    // Clamp thresholds (±6.0)
    localparam signed [DATA_WIDTH-1:0] CLAMP_POS = (6 <<< FRAC_WIDTH);
    localparam signed [DATA_WIDTH-1:0] CLAMP_NEG = -(6 <<< FRAC_WIDTH);

    reg [DATA_WIDTH-1:0] TANH_ROM [0:ROM_DEPTH-1];

    // Load ROM from hex
    initial begin
        $readmemh("./mem/tanh_lut_mem.hex", TANH_ROM);
    end
    
    // Use absolute value (symmetric LUT)
    wire signed [DATA_WIDTH-1:0] z_abs = z_in[DATA_WIDTH-1] ? -z_in : z_in;

    // Address Indexing Logic:
    // We want to capture the integer part and the most significant fractional bits.
    // For Q8.24, we used bits [26:17].
    // 26 = FRAC_WIDTH + 2
    // 17 = FRAC_WIDTH - 7
    // This maintains the same input range mapping for the LUT regardless of Q format.
    wire [ADDRESS_BITS-1:0] rom_address = z_abs[FRAC_WIDTH+2 : FRAC_WIDTH-7];
    
    wire signed [DATA_WIDTH-1:0] rom_data = TANH_ROM[rom_address];

    // Output: clamp then apply sign
    assign a_tanh =
        (z_in >= CLAMP_POS) ? MAX_POSITIVE_VAL :
        (z_in <= CLAMP_NEG) ? MAX_NEGATIVE_VAL :
        (z_in[DATA_WIDTH-1] ? -rom_data : rom_data);

endmodule