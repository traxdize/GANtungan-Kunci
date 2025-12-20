`timescale 1ns/1ps

module memory #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10
)(
    input wire clk, // Clock is now unused for reading, but kept for interface compatibility
    input wire [ADDR_WIDTH-1:0] addr,
    output reg signed [DATA_WIDTH-1:0] w1, w2, w3, w4, bias
);

    // CHANGED: "posedge clk" -> "*" (Combinational Logic)
    // This makes the weights available IMMEDIATELY when addr changes.
    always @(*) begin
        case(addr)
            // ============================================================
            // 1. GENERATOR HIDDEN (G2)
            // ============================================================
            10'd0: begin w1 = 32'hFFFFFA3B; w2 = 32'hFFFFFEBE; w3 = 0; w4 = 0; bias = 32'h0001DE6D; end // Neuron 1
            10'd1: begin w1 = 32'h00000073; w2 = 32'hFFFFFE3D; w3 = 0; w4 = 0; bias = 32'h0001A99D; end // Neuron 2
            10'd2: begin w1 = 32'hFFFFF96E; w2 = 32'hFFFFFBC8; w3 = 0; w4 = 0; bias = 32'hFFFE8C63; end // Neuron 3

            // ============================================================
            // 2. GENERATOR OUTPUT (G3)
            // ============================================================
            10'd3: begin w1 = 32'hFFFF3C6B; w2 = 32'hFFFF41A0; w3 = 32'h0000B800; w4 = 0; bias = 32'hFFFF34F4; end // Pixel 1
            10'd4: begin w1 = 32'h0001635B; w2 = 32'h0000F01E; w3 = 32'hFFFF7723; w4 = 0; bias = 32'h000231C0; end // Pixel 2
            10'd5: begin w1 = 32'hFFFF7444; w2 = 32'hFFFF5910; w3 = 32'h0000C78A; w4 = 0; bias = 32'hFFFEF864; end // Pixel 3
            10'd6: begin w1 = 32'h00017B45; w2 = 32'h000100AF; w3 = 32'hFFFF6405; w4 = 0; bias = 32'h0001F850; end // Pixel 4
            10'd7: begin w1 = 32'h0000A9A8; w2 = 32'h0000E423; w3 = 32'hFFFF5977; w4 = 0; bias = 32'h0000D1C8; end // Pixel 5
            10'd8: begin w1 = 32'h000180B3; w2 = 32'h0000EDA4; w3 = 32'hFFFF57AB; w4 = 0; bias = 32'h0001FBE8; end // Pixel 6
            10'd9: begin w1 = 32'hFFFF56F9; w2 = 32'hFFFF29B9; w3 = 32'h0000C122; w4 = 0; bias = 32'hFFFF3A61; end // Pixel 7
            10'd10:begin w1 = 32'h0001407F; w2 = 32'h0000F4FF; w3 = 32'hFFFF4C7E; w4 = 0; bias = 32'h000229CC; end // Pixel 8
            10'd11:begin w1 = 32'hFFFF3474; w2 = 32'hFFFF5D78; w3 = 32'h00009BB0; w4 = 0; bias = 32'hFFFF0B52; end // Pixel 9

            // ============================================================
            // 3. DISCRIMINATOR HIDDEN (D2)
            // ============================================================
            
            // --- Neuron 1 ---
            10'd12: begin w1=32'hFFFFDE48; w2=32'hFFFF5600; w3=32'hFFFFEE7C; w4=32'hFFFF6267; bias=0; end // Pass 1
            10'd13: begin w1=32'hFFFFE7F4; w2=32'hFFFF7A90; w3=32'h0000076C; w4=32'hFFFF646B; bias=0; end // Pass 2
            10'd14: begin w1=32'h0000185D; w2=0; w3=0; w4=0; bias=32'h0000A356; end                         // Pass 3

            // --- Neuron 2 ---
            10'd15: begin w1=32'hFFFFEB8C; w2=32'h0000B98B; w3=32'hFFFFEAE6; w4=32'h0000B414; bias=0; end // Pass 1
            10'd16: begin w1=32'h00001172; w2=32'h0000BCC5; w3=32'hFFFFEDBD; w4=32'h0000B649; bias=0; end // Pass 2
            10'd17: begin w1=32'hFFFFEF1A; w2=0; w3=0; w4=0; bias=32'hFFFD1536; end                         // Pass 3

            // --- Neuron 3 ---
            10'd18: begin w1=32'h0000DC04; w2=32'hFFFFF95D; w3=32'h0000B63F; w4=32'hFFFFC009; bias=0; end // Pass 1
            10'd19: begin w1=32'hFFFF5397; w2=32'hFFFFC008; w3=32'h00009847; w4=32'hFFFFC26A; bias=0; end // Pass 2
            10'd20: begin w1=32'h0000D5D9; w2=0; w3=0; w4=0; bias=32'hFFFFCF84; end                         // Pass 3

            // ============================================================
            // 4. DISCRIMINATOR OUTPUT (D3)
            // ============================================================
            10'd21: begin w1=32'hFFFE362F; w2=32'h00031DA1; w3=32'h00035113; w4=0; bias=32'hFFFFFA76; end

            default: begin w1=0; w2=0; w3=0; w4=0; bias=0; end
        endcase
    end
endmodule