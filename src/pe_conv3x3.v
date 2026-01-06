// File         : pe_conv3x3.v
// Description  : Pipelined 3x3 Convolution Processing Element with Bias (Q16.16)
// Standard     : Verilog-2001

module pe_conv3x3 (
    input  clk,
    input  rst_n,
    input  en,
    // Pixel Window (9 inputs)
    input  signed [31:0] p0, p1, p2, p3, p4, p5, p6, p7, p8,
    // Weights (9 inputs)
    input  signed [31:0] w0, w1, w2, w3, w4, w5, w6, w7, w8,
    // Bias
    input  signed [31:0] bias,
    // Results
    output reg signed [31:0] result,
    output reg valid_out
);

    // Pipeline Stage 1: Multiplication (Q16.16 * Q16.16 = Q32.32)
    reg signed [63:0] prod [0:8];
    reg signed [31:0] bias_q1;
    reg en_q1;

    // Pipeline Stage 2: Partial Summation
    reg signed [63:0] sum_a, sum_b, sum_c;
    reg en_q2;

    // Pipeline Stage 3: Final Accumulation and Bias Addition
    reg signed [63:0] final_sum;
    reg en_q3;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result     <= 32'd0;
            valid_out  <= 1'b0;
            en_q1      <= 1'b0;
            en_q2      <= 1'b0;
            en_q3      <= 1'b0;
            bias_q1    <= 32'd0;
            sum_a      <= 64'd0;
            sum_b      <= 64'd0;
            sum_c      <= 64'd0;
            final_sum  <= 64'd0;
            for (i = 0; i < 9; i = i + 1) prod[i] <= 64'd0;
        end else begin
            // Stage 1: Multipliers
            if (en) begin
                prod[0] <= p0 * w0;
                prod[1] <= p1 * w1;
                prod[2] <= p2 * w2;
                prod[3] <= p3 * w3;
                prod[4] <= p4 * w4;
                prod[5] <= p5 * w5;
                prod[6] <= p6 * w6;
                prod[7] <= p7 * w7;
                prod[8] <= p8 * w8;
                bias_q1 <= bias;
            end
            en_q1 <= en;

            // Stage 2: Adder Tree Part 1
            if (en_q1) begin
                sum_a <= prod[0] + prod[1] + prod[2];
                sum_b <= prod[3] + prod[4] + prod[5];
                sum_c <= prod[6] + prod[7] + prod[8];
            end
            en_q2 <= en_q1;

            // Stage 3: Final Sum + Bias (shifted to Q32.32)
            if (en_q2) begin
                final_sum <= sum_a + sum_b + sum_c + {{16{bias_q1[31]}}, bias_q1, 16'd0};
            end
            en_q3 <= en_q2;

            // Stage 4: Output and Truncation (Q32.32 to Q16.16)
            if (en_q3) begin
                result <= final_sum[47:16];
            end
            valid_out <= en_q3;
        end
    end

endmodule