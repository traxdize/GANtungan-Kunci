`timescale 1ns/1ps

module memory #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10
)(
    input wire clk,
    input wire [ADDR_WIDTH-1:0] addr,
    output reg signed [DATA_WIDTH-1:0] w1, w2, w3, w4, bias
);

    always @(posedge clk) begin
        case(addr)
            // Generator Hidden
            10'd0: begin w1 <= 32'h0001_0000; w2 <= 32'hFFFF_0000; w3 <= 0; w4 <= 0; bias <= 0; end
            10'd1: begin w1 <= 32'h0000_0000; w2 <= 32'h0000_2000; w3 <= 0; w4 <= 0; bias <= 0; end
            10'd2: begin w1 <= 32'h0000_0000; w2 <= 32'h0000_2000; w3 <= 0; w4 <= 0; bias <= 0; end

            // Generator Output
            10'd3: begin w1 <= 32'h0000_0000; w2 <= 32'h0000_2000; w3 <= 0; w4 <= 0; bias <= 0; end
            10'd4: begin w1 <= 32'h0000_0000; w2 <= 32'h0000_2000; w3 <= 0; w4 <= 0; bias <= 0; end
            10'd5: begin w1 <= 32'h0001_0000; w2 <= 32'hFFFF_0000; w3 <= 0; w4 <= 0; bias <= 0; end
            10'd6: begin w1 <= 32'h0001_0000; w2 <= 32'hFFFF_0000; w3 <= 0; w4 <= 0; bias <= 0; end
            10'd7: begin w1 <= 32'h0001_0000; w2 <= 32'hFFFF_0000; w3 <= 0; w4 <= 0; bias <= 0; end
            10'd8: begin w1 <= 32'h0001_0000; w2 <= 32'hFFFF_0000; w3 <= 0; w4 <= 0; bias <= 0; end
            10'd9: begin w1 <= 32'h0001_0000; w2 <= 32'hFFFF_0000; w3 <= 0; w4 <= 0; bias <= 0; end
            10'd10: begin w1 <= 32'h0001_0000; w2 <= 32'hFFFF_0000; w3 <= 0; w4 <= 0; bias <= 0; end
            10'd11: begin w1 <= 32'h0001_0000; w2 <= 32'hFFFF_0000; w3 <= 0; w4 <= 0; bias <= 0; end
            
            // Discriminator Hidden
            10'd12: begin w1 <= 32'h0001_0000; w2 <= 32'hFFFF_0000; w3 <= 0; w4 <= 0; bias <= 0; end
            10'd13: begin w1 <= 32'h0001_0000; w2 <= 32'hFFFF_0000; w3 <= 0; w4 <= 0; bias <= 0; end
            10'd14: begin w1 <= 32'h0001_0000; w2 <= 32'hFFFF_0000; w3 <= 0; w4 <= 0; bias <= 0; end
            10'd15: begin w1 <= 32'h0001_0000; w2 <= 32'hFFFF_0000; w3 <= 0; w4 <= 0; bias <= 0; end
            10'd16: begin w1 <= 32'h0001_0000; w2 <= 32'hFFFF_0000; w3 <= 0; w4 <= 0; bias <= 0; end
            10'd17: begin w1 <= 32'h0001_0000; w2 <= 32'hFFFF_0000; w3 <= 0; w4 <= 0; bias <= 0; end
            10'd18: begin w1 <= 32'h0001_0000; w2 <= 32'hFFFF_0000; w3 <= 0; w4 <= 0; bias <= 0; end
            10'd19: begin w1 <= 32'h0001_0000; w2 <= 32'hFFFF_0000; w3 <= 0; w4 <= 0; bias <= 0; end
            10'd20: begin w1 <= 32'h0001_0000; w2 <= 32'hFFFF_0000; w3 <= 0; w4 <= 0; bias <= 0; end
            
            // Discriminator Output
            10'd21: begin w1 <= 32'h0001_0000; w2 <= 32'hFFFF_0000; w3 <= 0; w4 <= 0; bias <= 0; end
            
            default: begin w1 <= 0; w2 <= 0; w3 <= 0; w4 <= 0; end
        endcase
    end
endmodule