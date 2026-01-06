// File         : weight_rom.v
// Description  : Weight ROM with zero-initialization.
// Standard     : Verilog-2001

module weight_rom (
    input  clk,
    input  is_generator,
    input  [7:0] layer_id,
    
    output reg signed [31:0] w0, w1, w2, w3, w4, w5, w6, w7, w8,
    output reg signed [31:0] bias,
    output reg signed [31:0] slope
);

    reg [31:0] gen_mem [0:1023];
    reg [31:0] disc_mem [0:511];
    integer i;

    initial begin
        // Clear memories before loading hex files to prevent X
        for (i = 0; i < 1024; i = i + 1) gen_mem[i] = 32'd0;
        for (i = 0; i < 512;  i = i + 1) disc_mem[i] = 32'd0;
        
        $readmemh("mem/all_weights_gen.hex", gen_mem);
        $readmemh("mem/all_weights_disc.hex", disc_mem);
    end

    wire [11:0] base_addr = layer_id << 4;

    always @(posedge clk) begin
        if (is_generator) begin
            w0 <= gen_mem[base_addr + 0]; w1 <= gen_mem[base_addr + 1];
            w2 <= gen_mem[base_addr + 2]; w3 <= gen_mem[base_addr + 3];
            w4 <= gen_mem[base_addr + 4]; w5 <= gen_mem[base_addr + 5];
            w6 <= gen_mem[base_addr + 6]; w7 <= gen_mem[base_addr + 7];
            w8 <= gen_mem[base_addr + 8]; bias <= gen_mem[base_addr + 9];
            slope <= gen_mem[base_addr + 10];
        end else begin
            w0 <= disc_mem[base_addr + 0]; w1 <= disc_mem[base_addr + 1];
            w2 <= disc_mem[base_addr + 2]; w3 <= disc_mem[base_addr + 3];
            w4 <= disc_mem[base_addr + 4]; w5 <= disc_mem[base_addr + 5];
            w6 <= disc_mem[base_addr + 6]; w7 <= disc_mem[base_addr + 7];
            w8 <= disc_mem[base_addr + 8]; bias <= disc_mem[base_addr + 9];
            slope <= disc_mem[base_addr + 10];
        end
    end
endmodule