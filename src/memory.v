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
            // ============================================================
            // 1. GENERATOR HIDDEN (G2) - Address 0-2
            // Strategy: Kill the noise. Output 0.
            // ============================================================
            10'd0: begin w1 <= 0; w2 <= 0; w3 <= 0; w4 <= 0; bias <= 0; end
            10'd1: begin w1 <= 0; w2 <= 0; w3 <= 0; w4 <= 0; bias <= 0; end
            10'd2: begin w1 <= 0; w2 <= 0; w3 <= 0; w4 <= 0; bias <= 0; end

            // ============================================================
            // 2. GENERATOR OUTPUT (G3) - Address 3-11
            // Strategy: Use BIAS to force the Checkerboard Pattern
            // [ B W B ]
            // [ W B W ]
            // [ B W B ]
            // ============================================================
            
            // Row 1
            10'd3: begin w1<=0; w2<=0; w3<=0; w4<=0; bias<=32'hFFFC_0000; end // Pix 1: BLACK (-4.0)
            10'd4: begin w1<=0; w2<=0; w3<=0; w4<=0; bias<=32'h0004_0000; end // Pix 2: WHITE (+4.0)
            10'd5: begin w1<=0; w2<=0; w3<=0; w4<=0; bias<=32'hFFFC_0000; end // Pix 3: BLACK (-4.0)

            // Row 2
            10'd6: begin w1<=0; w2<=0; w3<=0; w4<=0; bias<=32'h0004_0000; end // Pix 4: WHITE (+4.0)
            10'd7: begin w1<=0; w2<=0; w3<=0; w4<=0; bias<=32'hFFFC_0000; end // Pix 5: BLACK (-4.0)
            10'd8: begin w1<=0; w2<=0; w3<=0; w4<=0; bias<=32'h0004_0000; end // Pix 6: WHITE (+4.0)

            // Row 3
            10'd9: begin w1<=0; w2<=0; w3<=0; w4<=0; bias<=32'hFFFC_0000; end // Pix 7: BLACK (-4.0)
            10'd10:begin w1<=0; w2<=0; w3<=0; w4<=0; bias<=32'h0004_0000; end // Pix 8: WHITE (+4.0)
            10'd11:begin w1<=0; w2<=0; w3<=0; w4<=0; bias<=32'hFFFC_0000; end // Pix 9: BLACK (-4.0)

            // ============================================================
            // 3. DISCRIMINATOR HIDDEN (D2) - Address 12-20
            // Strategy: "Matched Filter". Weights match the image pattern.
            // -1 for Black pixels, +1 for White pixels.
            // ============================================================
            
            // --- Neuron 1 (The Detector) ---
            // Pass 1: Pixels 1-4 (B, W, B, W) -> Weights: -1, 1, -1, 1
            10'd12: begin 
                w1 <= 32'hFFFF_0000; // -1
                w2 <= 32'h0001_0000; //  1
                w3 <= 32'hFFFF_0000; // -1
                w4 <= 32'h0001_0000; //  1
                bias <= 0; 
            end
            
            // Pass 2: Pixels 5-8 (B, W, B, W) -> Weights: -1, 1, -1, 1
            10'd13: begin 
                w1 <= 32'hFFFF_0000; // -1
                w2 <= 32'h0001_0000; //  1
                w3 <= 32'hFFFF_0000; // -1
                w4 <= 32'h0001_0000; //  1
                bias <= 0; 
            end 

            // Pass 3: Pixel 9 (B) -> Weight: -1
            10'd14: begin 
                w1 <= 32'hFFFF_0000; // -1
                w2 <= 0; w3 <= 0; w4 <= 0; 
                bias <= 0; 
            end 

            // --- Neurons 2 & 3 (Unused / Dummy) ---
            10'd15: begin w1<=0; w2<=0; w3<=0; w4<=0; bias<=0; end 
            10'd16: begin w1<=0; w2<=0; w3<=0; w4<=0; bias<=0; end 
            10'd17: begin w1<=0; w2<=0; w3<=0; w4<=0; bias<=0; end 
            10'd18: begin w1<=0; w2<=0; w3<=0; w4<=0; bias<=0; end 
            10'd19: begin w1<=0; w2<=0; w3<=0; w4<=0; bias<=0; end 
            10'd20: begin w1<=0; w2<=0; w3<=0; w4<=0; bias<=0; end 

            // ============================================================
            // 4. DISCRIMINATOR OUTPUT (D3) - Address 21
            // Strategy: Neuron 1 found a match (Sum=9), so weight it high.
            // ============================================================
            10'd21: begin 
                w1 <= 32'h0004_0000; // High weight (+4.0) for Neuron 1
                w2 <= 0; 
                w3 <= 0; 
                w4 <= 0; 
                bias <= 0; 
            end
            
            default: begin w1<=0; w2<=0; w3<=0; w4<=0; bias<=0; end
        endcase
    end
endmodule