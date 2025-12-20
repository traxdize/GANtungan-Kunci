`timescale 1ns/1ps

module memory #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10
)(
    input wire clk, // Unused for combinational read
    input wire [ADDR_WIDTH-1:0] addr,
    output reg signed [DATA_WIDTH-1:0] w1, w2, w3, w4, bias
);

    // Combinational logic for immediate weight availability
    always @(*) begin
        case(addr)
            // ============================================================
            // 1. GENERATOR HIDDEN (G2)
            // ============================================================
            // Neuron 1
            10'd0: begin 
                w1 = 32'h00000368; 
                w2 = 32'h00000299; 
                w3 = 0; w4 = 0; 
                bias = 32'h00021391; 
            end 
            // Neuron 2
            10'd1: begin 
                w1 = 32'h0000202E; 
                w2 = 32'h000003D2; 
                w3 = 0; w4 = 0; 
                bias = 32'hFFFFCCDC; 
            end 
            // Neuron 3
            10'd2: begin 
                w1 = 32'hFFFFDC57; 
                w2 = 32'hFFFFEA04; 
                w3 = 0; w4 = 0; 
                bias = 32'h00008C1C; 
            end 

            // ============================================================
            // 2. GENERATOR OUTPUT (G3)
            // ============================================================
            // Pixel 1
            10'd3: begin 
                w1 = 32'hFFFEC358; 
                w2 = 32'h00000DA2; 
                w3 = 32'hFFFFDAAA; 
                w4 = 0; 
                bias = 32'hFFFE2C0B; 
            end 
            // Pixel 2
            10'd4: begin 
                w1 = 32'h0001479A; 
                w2 = 32'hFFFFEDA0; 
                w3 = 32'h000043B0; 
                w4 = 0; 
                bias = 32'h0001B139; 
            end 
            // Pixel 3
            10'd5: begin 
                w1 = 32'h00017714; 
                w2 = 32'h000013AD; 
                w3 = 32'h000042BB; 
                w4 = 0; 
                bias = 32'h00019574; 
            end 
            // Pixel 4
            10'd6: begin 
                w1 = 32'h00016FA4; 
                w2 = 32'h00000F95; 
                w3 = 32'h00002B78; 
                w4 = 0; 
                bias = 32'h0001A2D2; 
            end 
            // Pixel 5
            10'd7: begin 
                w1 = 32'hFFFEAC8E; 
                w2 = 32'h00003486; 
                w3 = 32'hFFFFDA5C; 
                w4 = 0; 
                bias = 32'hFFFE4B6A; 
            end 
            // Pixel 6
            10'd8: begin 
                w1 = 32'h000174EB; 
                w2 = 32'hFFFFFCC6; 
                w3 = 32'h00001F6B; 
                w4 = 0; 
                bias = 32'h0001A085; 
            end 
            // Pixel 7
            10'd9: begin 
                w1 = 32'h000146E2; 
                w2 = 32'hFFFFD31D; 
                w3 = 32'h00003F63; 
                w4 = 0; 
                bias = 32'h0001B4AB; 
            end 
            // Pixel 8
            10'd10: begin 
                w1 = 32'h00013BF6; 
                w2 = 32'hFFFFFD25; 
                w3 = 32'h000017A0; 
                w4 = 0; 
                bias = 32'h0001D914; 
            end 
            // Pixel 9
            10'd11: begin 
                w1 = 32'hFFFED982; 
                w2 = 32'h00003650; 
                w3 = 32'hFFFFBD91; 
                w4 = 0; 
                bias = 32'hFFFE2D04; 
            end

            // ============================================================
            // 3. DISCRIMINATOR HIDDEN (D2)
            // ============================================================
            
            // --- Neuron 1 ---
            // Pass 1
            10'd12: begin 
                w1=32'h000018EE; w2=32'hFFFFB014; w3=32'hFFFF9763; w4=32'hFFFFC48A; 
                bias=0; 
            end 
            // Pass 2
            10'd13: begin 
                w1=32'h00004246; w2=32'hFFFFD8F0; w3=32'hFFFFB998; w4=32'hFFFFC6DF; 
                bias=0; 
            end 
            // Pass 3 (Includes Bias)
            10'd14: begin 
                w1=32'h00004301; w2=0; w3=0; w4=0; 
                bias=32'h0002115E; 
            end 

            // --- Neuron 2 ---
            // Pass 1
            10'd15: begin 
                w1=32'hFFFF8D34; w2=32'h0000452C; w3=32'h0000364F; w4=32'h000048C3; 
                bias=0; 
            end 
            // Pass 2
            10'd16: begin 
                w1=32'hFFFFBBA9; w2=32'h00005C7F; w3=32'h00002735; w4=32'h00005BA1; 
                bias=0; 
            end 
            // Pass 3 (Includes Bias)
            10'd17: begin 
                w1=32'hFFFFC51B; w2=0; w3=0; w4=0; 
                bias=32'hFFFD8C8B; 
            end 

            // --- Neuron 3 ---
            // Pass 1
            10'd18: begin 
                w1=32'h0000458B; w2=32'hFFFFD3E4; w3=32'hFFFFC879; w4=32'hFFFFB117; 
                bias=0; 
            end 
            // Pass 2
            10'd19: begin 
                w1=32'h0000482C; w2=32'hFFFFB1BF; w3=32'hFFFFA595; w4=32'hFFFFBF41; 
                bias=0; 
            end 
            // Pass 3 (Includes Bias)
            10'd20: begin 
                w1=32'h00004A3A; w2=0; w3=0; w4=0; 
                bias=32'h00024FFD; 
            end 

            // ============================================================
            // 4. DISCRIMINATOR OUTPUT (D3)
            // ============================================================
            10'd21: begin 
                w1=32'hFFFDA679; 
                w2=32'h0002BCA0; 
                w3=32'hFFFD67DC; 
                w4=0; 
                bias=32'hFFFEF456; 
            end

            default: begin w1=0; w2=0; w3=0; w4=0; bias=0; end
        endcase
    end
endmodule