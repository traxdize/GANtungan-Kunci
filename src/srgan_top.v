// File         : srgan_top.v
// Description  : Integrated Top-Level with Simulation Streaming Logger.
// Standard     : Verilog-2001

`include "srgan_controller.v"
`include "compute_core.v"
`include "ram_block.v"
`include "weight_rom.v"

module srgan_top (
    input  clk,
    input  rst_n,

    input  uart_rx_valid,
    input  signed [31:0] uart_rx_data,
    output gen_done,
    output disc_done,
    input  save_ack,
    output ping_pong_sel,
    output signed [31:0] final_result
);

    wire [7:0]  layer_id;
    wire        is_generator, we_ram_ctrl, compute_en, core_rst_n, is_loading, valid_out_core;
    wire [11:0] addr_write_ctrl, addr_read_ctrl;
    wire [5:0]  img_width;
    wire [1:0]  act_type;
    wire signed [31:0] pixel_to_core, pixel_from_core, slope, bias;
    wire signed [31:0] w [0:8];
    wire signed [31:0] r_ping_out, r_pong_out;
    reg  signed [31:0] r_ping_in, r_pong_in;
    reg  we_ping, we_pong;

    srgan_controller ctrl (
        .clk(clk), .rst_n(rst_n), .uart_rx_valid(uart_rx_valid), .gen_done(gen_done), .disc_done(disc_done), 
        .save_ack(save_ack), .layer_id(layer_id), .is_generator(is_generator), .we_ram(we_ram_ctrl),
        .addr_write(addr_write_ctrl), .addr_read(addr_read_ctrl), .ping_pong_sel(ping_pong_sel),
        .img_width(img_width), .act_type(act_type), .compute_en(compute_en), .core_rst_n(core_rst_n),
        .is_loading(is_loading), .valid_out_core(valid_out_core), .pixel_out_core(pixel_from_core)
    );

    weight_rom rom (
        .clk(clk), .is_generator(is_generator), .layer_id(layer_id),
        .w0(w[0]), .w1(w[1]), .w2(w[2]), .w3(w[3]), .w4(w[4]), .w5(w[5]), .w6(w[6]), .w7(w[7]), .w8(w[8]),
        .bias(bias), .slope(slope)
    );

    compute_core core (
        .clk(clk), .rst_n(core_rst_n), .en(compute_en), .img_width(img_width), .act_type(act_type), .slope(slope),
        .pixel_in(pixel_to_core), .valid_in(compute_en), .bias(bias), .pixel_out(pixel_from_core), .valid_out(valid_out_core),
        .w0(w[0]), .w1(w[1]), .w2(w[2]), .w3(w[3]), .w4(w[4]), .w5(w[5]), .w6(w[6]), .w7(w[7]), .w8(w[8])
    );

    assign pixel_to_core = (ping_pong_sel == 1'b0) ? r_ping_out : r_pong_out;

    always @(*) begin
        we_ping = 0; we_pong = 0; r_ping_in = 0; r_pong_in = 0;
        if (is_loading) begin we_ping = we_ram_ctrl; r_ping_in = uart_rx_data; end
        else if (ping_pong_sel == 0) begin we_pong = we_ram_ctrl; r_pong_in = pixel_from_core; end
        else begin we_ping = we_ram_ctrl; r_ping_in = pixel_from_core; end
    end

    ram_block ping ( .clk(clk), .we_a(we_ping), .addr_a(addr_write_ctrl), .data_in_a(r_ping_in), .addr_b(addr_read_ctrl), .data_out_b(r_ping_out) );
    ram_block pong ( .clk(clk), .we_a(we_pong), .addr_a(addr_write_ctrl), .data_in_a(r_pong_in), .addr_b(addr_read_ctrl), .data_out_b(r_pong_out) );

    assign final_result = pixel_from_core;

    // --- SIMULATION STREAMING LOGGER ---
    // synthesis translate_off
    integer log_fd;
    initial log_fd = $fopen("generator_stream.log", "w");
    always @(posedge clk) begin
        if (valid_out_core && is_generator && layer_id == 20) begin
            $fdisplay(log_fd, "%h", pixel_from_core);
        end
    end
    // synthesis translate_on

endmodule