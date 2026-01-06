// File         : srgan_controller.v
// Description  : Main FSM with Startup/Flush Latency handling.
// Standard     : Verilog-2001

module srgan_controller (
    input  clk,
    input  rst_n,

    input  uart_rx_valid,
    output reg gen_done,
    output reg disc_done,
    input  save_ack,

    output reg [7:0] layer_id,
    output reg is_generator,

    output reg we_ram,
    output reg [11:0] addr_write,
    output reg [11:0] addr_read,
    output reg ping_pong_sel, 
    
    output reg [5:0]  img_width,
    output reg [1:0]  act_type,
    output reg compute_en,
    output reg core_rst_n,   
    output reg is_loading,
    input  valid_out_core,
    input  signed [31:0] pixel_out_core
);

    localparam ST_IDLE       = 4'd0;
    localparam ST_LOAD_INPUT = 4'd1;
    localparam ST_RUN_LAYER  = 4'd2;
    localparam ST_GEN_SAVE   = 4'd3;
    localparam ST_HANDOFF    = 4'd4;
    localparam ST_DISC_SAVE  = 4'd5;

    reg [3:0]  state;
    reg [7:0]  layer_count;
    reg [11:0] read_pixel_cnt;
    reg [11:0] write_pixel_cnt;
    reg [5:0]  current_img_w;

    always @(*) begin
        if (is_generator) begin
            case (layer_count)
                8'd18:   current_img_w = 6'd8; 
                8'd19:   current_img_w = 6'd16;
                8'd20:   current_img_w = 6'd32;
                default: current_img_w = 6'd8; 
            endcase
            act_type = (layer_count == 20) ? 2'd1 : 2'd0;
        end else begin
            current_img_w = 6'd32;
            act_type = (layer_count == 8) ? 2'd2 : 2'd0;
        end
        img_width = current_img_w;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE; layer_id <= 0; is_generator <= 1;
            compute_en <= 0; core_rst_n <= 0; gen_done <= 0; disc_done <= 0;
            read_pixel_cnt <= 0; write_pixel_cnt <= 0; layer_count <= 0;
            ping_pong_sel <= 0; is_loading <= 0;
        end else begin
            case (state)
                ST_IDLE: if (uart_rx_valid) begin state <= ST_LOAD_INPUT; is_loading <= 1; read_pixel_cnt <= 0; end
                
                ST_LOAD_INPUT: begin
                    if (read_pixel_cnt == 191) begin 
                        state <= ST_RUN_LAYER; is_loading <= 0; core_rst_n <= 1;
                        read_pixel_cnt <= 0; write_pixel_cnt <= 0;
                    end else read_pixel_cnt <= read_pixel_cnt + 1;
                end

                ST_RUN_LAYER: begin
                    compute_en <= 1;
                    layer_id <= layer_count;
                    
                    // Feed data + 64 cycles to flush pipeline
                    if (read_pixel_cnt < (current_img_w * current_img_w * 3) + 64) read_pixel_cnt <= read_pixel_cnt + 1;

                    if (valid_out_core) begin
                        if (write_pixel_cnt == (current_img_w * current_img_w * 3) - 1) begin
                            write_pixel_cnt <= 0; read_pixel_cnt <= 0;
                            ping_pong_sel <= ~ping_pong_sel; core_rst_n <= 0; 
                            if (is_generator && layer_count == 20) state <= ST_GEN_SAVE;
                            else if (!is_generator && layer_count == 8) state <= ST_DISC_SAVE;
                            else layer_count <= layer_count + 1;
                        end else write_pixel_cnt <= write_pixel_cnt + 1;
                    end
                end

                ST_GEN_SAVE: if (save_ack) begin state <= ST_HANDOFF; gen_done <= 0; end else gen_done <= 1;
                
                ST_HANDOFF: begin is_generator <= 0; layer_count <= 0; core_rst_n <= 1; state <= ST_RUN_LAYER; end

                ST_DISC_SAVE: if (save_ack) begin disc_done <= 0; state <= ST_IDLE; end else disc_done <= 1;
            endcase
            if (state == ST_RUN_LAYER && !core_rst_n) core_rst_n <= 1;
        end
    end

    always @(*) begin
        addr_read = (read_pixel_cnt >= (current_img_w * current_img_w * 3)) ? 0 : read_pixel_cnt;
        addr_write = (state == ST_LOAD_INPUT) ? read_pixel_cnt : write_pixel_cnt;
        we_ram = (state == ST_LOAD_INPUT) ? 1 : valid_out_core;
    end
endmodule