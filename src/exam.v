`timescale 1ns/1ps

module gan_memori #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10
) (
    input wire clk,
    input wire [ADDR_WIDTH-1:0] addr,
    // We output 4 weights + 1 bias simultaneously to feed the Processor
    output reg signed [DATA_WIDTH-1:0] w1, w2, w3, w4, bias
);

    always @(posedge clk) begin
        case(addr)
            // --- Generator Hidden Layer (G2) ---
            // 2 inputs (Noise), so w3 and w4 are 0.
            10'd0: begin w1 <= 32'h0001_0000; w2 <= 32'hFFFF_0000; w3 <= 0; w4 <= 0; bias <= 0; end // Placeholder
            10'd1: begin w1 <= 32'h0000_8000; w2 <= 32'h0000_2000; w3 <= 0; w4 <= 0; bias <= 0; end
            10'd2: begin w1 <= 32'hFFFF_8000; w2 <= 32'h0001_0000; w3 <= 0; w4 <= 0; bias <= 0; end

            // --- Generator Output Layer (G3) ---
            // 3 inputs (from G2), so w4 is 0.
            // Addresses 3 to 11 (9 neurons)
            10'd3: begin w1 <= 32'h0000_4000; w2 <= 32'h0000_4000; w3 <= 32'h0000_4000; w4 <= 0; bias <= 0; end
            // ... (Repeat for addresses 4-11) ...
            
            // --- Discriminator Hidden Layer (D2) ---
            // 9 inputs. Requires 3 passes per neuron.
            // Neuron 1 Pass 1 (Pixels 1-4)
            10'd12: begin w1 <= 32'h0001_0000; w2 <= 32'h0001_0000; w3 <= 32'h0001_0000; w4 <= 32'h0001_0000; bias <= 0; end 
            // Neuron 1 Pass 2 (Pixels 5-8)
            10'd13: begin w1 <= 32'h0001_0000; w2 <= 32'h0001_0000; w3 <= 32'h0001_0000; w4 <= 32'h0001_0000; bias <= 0; end 
            // Neuron 1 Pass 3 (Pixel 9 + Bias)
            10'd14: begin w1 <= 32'h0001_0000; w2 <= 0; w3 <= 0; w4 <= 0; bias <= 32'h0000_5000; end 

            // ... (Repeat for Neurons 2 and 3, Addresses 15-20) ...

            // --- Discriminator Output Layer (D3) ---
            // 3 inputs (from D2)
            10'd21: begin w1 <= 32'h0002_0000; w2 <= 32'h0002_0000; w3 <= 32'h0002_0000; w4 <= 0; bias <= 0; end

            default: begin w1 <= 0; w2 <= 0; w3 <= 0; w4 <= 0; bias <= 0; end
        endcase
    end

endmodule