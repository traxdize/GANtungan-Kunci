`timescale 1ns/1ps

// Note: Ensure line_buffer.v is in the same directory or adjust include path
`include "line_buffer.v"

module tb_line_buffer();
    reg clk;
    reg rst_n;
    reg en;
    reg [5:0] img_width;
    reg signed [31:0] pixel_in;
    reg valid_in;

    wire signed [31:0] p0, p1, p2, p3, p4, p5, p6, p7, p8;
    wire window_ready;

    line_buffer uut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .img_width(img_width),
        .pixel_in(pixel_in),
        .valid_in(valid_in),
        .p0(p0), .p1(p1), .p2(p2), 
        .p3(p3), .p4(p4), .p5(p5), 
        .p6(p6), .p7(p7), .p8(p8),
        .window_ready(window_ready)
    );

    always #5 clk = ~clk;

    integer row, col;
    integer pixel_counter;

    initial begin
        // Initialize
        clk = 0; rst_n = 0; en = 0;
        img_width = 6'd8; // Test with 8x8 image
        pixel_in = 32'd0;
        valid_in = 1'b0;
        pixel_counter = 1;

        #20 rst_n = 1;
        #10 en = 1;

        // Feed 8x8 image pixels (1 to 64)
        for (row = 0; row < 8; row = row + 1) begin
            for (col = 0; col < 8; col = col + 1) begin
                @(posedge clk);
                pixel_in = pixel_counter;
                valid_in = 1'b1;
                pixel_counter = pixel_counter + 1;
            end
        end

        @(posedge clk);
        valid_in = 1'b0;

        #100 $finish;
    end

    // Monitor Output
    always @(posedge clk) begin
        if (window_ready) begin
            $display("Time: %0t | Window Ready! Centre (p4): %d | Row: %d Col: %d", 
                      $time, p4, (p4-1)/8, (p4-1)%8);
            $display("  [%2d %2d %2d]", p0, p1, p2);
            $display("  [%2d %2d %2d]", p3, p4, p5);
            $display("  [%2d %2d %2d]", p6, p7, p8);
        end
    end

endmodule