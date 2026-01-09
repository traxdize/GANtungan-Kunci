// File: memory.v
// Description: memory module reading weights and biases from hex files

`timescale 1ns/1ps

module memory #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter MEM_DEPTH  = 32
)(
    input wire clk, 
    input wire [ADDR_WIDTH-1:0] addr,
    output reg signed [DATA_WIDTH-1:0] w1, w2, w3, w4, bias
);

    // Internal memory arrays
    reg [DATA_WIDTH-1:0] mem_w1   [0:MEM_DEPTH-1];
    reg [DATA_WIDTH-1:0] mem_w2   [0:MEM_DEPTH-1];
    reg [DATA_WIDTH-1:0] mem_w3   [0:MEM_DEPTH-1];
    reg [DATA_WIDTH-1:0] mem_w4   [0:MEM_DEPTH-1];
    reg [DATA_WIDTH-1:0] mem_bias [0:MEM_DEPTH-1];

    // Initialize memory from hex files
    initial begin
        $readmemh("mem/w1.hex",   mem_w1);
        $readmemh("mem/w2.hex",   mem_w2);
        $readmemh("mem/w3.hex",   mem_w3);
        $readmemh("mem/w4.hex",   mem_w4);
        $readmemh("mem/bias.hex", mem_bias);
    end

    // Combinational read logic
    always @(*) begin
        if (addr < MEM_DEPTH) begin
            w1   = mem_w1[addr];
            w2   = mem_w2[addr];
            w3   = mem_w3[addr];
            w4   = mem_w4[addr];
            bias = mem_bias[addr];
        end else begin
            w1 = 0; w2 = 0; w3 = 0; w4 = 0; bias = 0;
        end
    end

endmodule