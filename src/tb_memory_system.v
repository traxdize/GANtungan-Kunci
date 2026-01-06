`timescale 1ns/1ps

`include "ram_block.v"
`include "weight_rom.v"

module tb_memory_system();
    reg clk;
    reg rst_n;
    
    // RAM Signals
    reg we_a;
    reg [11:0] addr_a, addr_b;
    reg [31:0] data_in_a;
    wire [31:0] data_out_b;

    // ROM Signals
    reg is_gen;
    reg [7:0] layer_id;
    wire [31:0] w0, bias, slope;

    ram_block ram_inst (
        .clk(clk),
        .we_a(we_a), .addr_a(addr_a), .data_in_a(data_in_a),
        .addr_b(addr_b), .data_out_b(data_out_b)
    );

    weight_rom rom_inst (
        .clk(clk),
        .is_generator(is_gen),
        .layer_id(layer_id),
        .w0(w0), .bias(bias), .slope(slope)
        // Others omitted for brevity in TB display
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; we_a = 0; addr_a = 0; addr_b = 0;
        is_gen = 1; layer_id = 0;

        #20;
        // Test RAM Write/Read
        @(posedge clk);
        we_a = 1; addr_a = 12'hABC; data_in_a = 32'hDEADBEEF;
        @(posedge clk);
        we_a = 0; addr_b = 12'hABC;
        @(posedge clk);
        #1;
        $display("RAM Read at ABC: %h (Expected DEADBEEF)", data_out_b);

        // Test ROM Access (Assuming hex files are present)
        layer_id = 8'd0;
        @(posedge clk);
        #2;
        $display("ROM Layer 0 - W0: %h, Bias: %h, Slope: %h", w0, bias, slope);

        #50 $finish;
    end
endmodule