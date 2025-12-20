// File: sigmoid_lut.v
// Description: Sigmoid LUT for Q1.15.16 format (32-bit).

module sigmoid_lut (
    input  signed [31:0] z_in,   // Input Q16.16
    output signed [31:0] a_sigmoid // Output Q16.16
);
    localparam ADDRESS_BITS = 10;
    localparam DATA_WIDTH   = 32;
    localparam ROM_DEPTH    = 1 << ADDRESS_BITS;

    // Q16.16 Constants
    localparam SIGMOID_MAX_VAL = 32'h00010000; // 1.0
    localparam SIGMOID_MIN_VAL = 32'h00000000; // 0.0
    
    // Clamping Thresholds (+/- 6.0)
    localparam POS_CLAMP_THRESHOLD = 32'h00060000; // +6.0
    localparam NEG_CLAMP_THRESHOLD = 32'hFFFA0000; // -6.0

    reg [DATA_WIDTH-1:0] SIGMOID_ROM [0:ROM_DEPTH-1];

    initial begin
        // Ensure you generated this file using the Python script provided
        $readmemh("mem/sigmoid_lut_mem.hex", SIGMOID_ROM);
    end

    // --- SYMMETRY LOGIC ---
    wire is_negative = z_in[31];
    
    // Calculate Absolute Value for lookup
    wire signed [31:0] z_abs = is_negative ? -z_in : z_in;

    // Address Generation (Q16.16)
    // Slice [22:13] matches the resolution of 0.125 per LSB
    wire [ADDRESS_BITS-1:0] rom_address = z_abs[22:13];

    // Read ROM
    wire signed [31:0] rom_data = SIGMOID_ROM[rom_address];

    assign a_sigmoid = 
        // Case 1: Positive Saturation (z > 6.0)
        (z_in >= $signed(POS_CLAMP_THRESHOLD)) ? SIGMOID_MAX_VAL :
        
        // Case 2: Negative Saturation (z < -6.0)
        (z_in <= $signed(NEG_CLAMP_THRESHOLD)) ? SIGMOID_MIN_VAL :
        
        // Case 3: Lookup with Symmetry
        // Sigmoid(-x) = 1.0 - Sigmoid(|x|)
        (is_negative ? (SIGMOID_MAX_VAL - rom_data) : rom_data);

endmodule