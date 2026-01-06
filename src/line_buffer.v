// File         : line_buffer.v
// Description  : 3x3 Sliding Window with Zero Padding (Same Padding).
// Standard     : Verilog-2001

module line_buffer (
    input  clk,
    input  rst_n,
    input  en,
    input  [5:0]  img_width,
    input  signed [31:0] pixel_in,
    input  valid_in,
    
    output signed [31:0] p0, p1, p2, p3, p4, p5, p6, p7, p8,
    output reg window_ready
);

    reg signed [31:0] row0 [0:31];
    reg signed [31:0] row1 [0:31];
    reg signed [31:0] win [0:2][0:2];

    reg [5:0]  col_ptr;
    reg [11:0] count_in;
    reg [5:0]  curr_row, curr_col;

    // Zero Padding Logic: If window center is on an edge, substitute zeros for neighbors
    wire is_top    = (curr_row == 0);
    wire is_bottom = (curr_row == img_width - 1);
    wire is_left   = (curr_col == 0);
    wire is_right  = (curr_col == img_width - 1);

    assign p0 = (is_top    || is_left)  ? 32'd0 : win[0][0];
    assign p1 = (is_top)                ? 32'd0 : win[0][1];
    assign p2 = (is_top    || is_right) ? 32'd0 : win[0][2];
    assign p3 = (is_left)               ? 32'd0 : win[1][0];
    assign p4 =                                   win[1][1]; // Center
    assign p5 = (is_right)              ? 32'd0 : win[1][2];
    assign p6 = (is_bottom || is_left)  ? 32'd0 : win[2][0];
    assign p7 = (is_bottom)             ? 32'd0 : win[2][1];
    assign p8 = (is_bottom || is_right) ? 32'd0 : win[2][2];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_ptr <= 0; count_in <= 0; window_ready <= 0;
            curr_row <= 0; curr_col <= 0;
            for (integer i=0; i<32; i=i+1) begin row0[i] <= 0; row1[i] <= 0; end
            for (integer i=0; i<3; i=i+1) begin win[i][0] <= 0; win[i][1] <= 0; win[i][2] <= 0; end
        end else if (en) begin
            if (valid_in) begin
                win[0][0] <= win[0][1]; win[0][1] <= win[0][2];
                win[1][0] <= win[1][1]; win[1][1] <= win[1][2];
                win[2][0] <= win[2][1]; win[2][1] <= win[2][2];

                win[2][2] <= pixel_in;
                win[1][2] <= row1[col_ptr];
                win[0][2] <= row0[col_ptr];

                row0[col_ptr] <= row1[col_ptr];
                row1[col_ptr] <= pixel_in;

                col_ptr  <= (col_ptr == img_width - 1) ? 0 : col_ptr + 1;
                count_in <= count_in + 1;
            end

            // window_ready asserts once the first row+1 pixel is loaded to center the kernel
            if (count_in > img_width) begin
                window_ready <= valid_in;
                if (valid_in) begin
                    if (curr_col == img_width - 1) begin curr_col <= 0; curr_row <= curr_row + 1; end
                    else curr_col <= curr_col + 1;
                end
            end else begin
                window_ready <= 0;
            end
        end
    end
endmodule