// File         : tb_srgan_full.v
// Description  : Corrected End-to-end testbench for SRGAN.
// Standard     : Verilog-2001

`timescale 1ns/1ps
`include "srgan_top.v"

module tb_srgan_full();
    reg clk;
    reg rst_n;

    reg                uart_rx_valid;
    reg  signed [31:0] uart_rx_data;
    wire               gen_done;
    wire               disc_done;
    reg                save_ack;
    wire               ping_pong_sel;
    wire signed [31:0] final_result;

    reg [31:0] input_buffer [0:3071];

    srgan_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx_valid(uart_rx_valid),
        .uart_rx_data(uart_rx_data),
        .gen_done(gen_done),
        .disc_done(disc_done),
        .save_ack(save_ack),
        .ping_pong_sel(ping_pong_sel),
        .final_result(final_result)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Monitor Block using correct hierarchical paths
    always @(posedge clk) begin
        if (uut.valid_out_core) begin
            $display("[%0t] MONITOR | Layer: %0d | Pix_Cnt: %4d | Val: %h", 
                     $time, uut.layer_id, uut.ctrl.write_pixel_cnt, uut.pixel_from_core);
            
            if (uut.pixel_from_core === 32'hxxxx_xxxx) begin
                $display("[%0t] !!! CRITICAL ERROR: X detected at Layer %0d !!!", $time, uut.layer_id);
            end
        end
    end

    initial begin
        $dumpfile("srgan_waveform.vcd");
        $dumpvars(0, tb_srgan_full);

        // System Initialization
        rst_n = 0;
        uart_rx_valid = 0;
        uart_rx_data = 32'd0;
        save_ack = 0;

        $readmemh("mem/tb_input_gen.hex", input_buffer);

        #100 rst_n = 1;
        #20;

        $display("[%0t] PHASE 1: Loading 8x8x3 Input Image...", $time);
        @(posedge clk);
        uart_rx_valid = 1;
        for (integer i = 0; i < 192; i = i + 1) begin
            uart_rx_data = input_buffer[i];
            @(posedge clk);
        end
        uart_rx_valid = 0;

        $display("[%0t] PHASE 2: Generator Inference Running...", $time);
        wait(gen_done);
        
        // Use the internal module tasks to bypass hierarchical indexing limitations
        if (ping_pong_sel == 1'b0) uut.ping.save_to_file("hardware_gen_out.hex", 3072);
        else                       uut.pong.save_to_file("hardware_gen_out.hex", 3072);

        #100;
        save_ack = 1;
        #20;
        save_ack = 0;

        $display("[%0t] PHASE 3: Discriminator Inference Running...", $time);
        wait(disc_done);

        $display("\n==================================================");
        $display("FINAL SRGAN OUTPUT (Discriminator Sigmoid): %h", final_result);
        $display("Probability of 'Real': %f", final_result / 65536.0);
        $display("==================================================\n");

        #100;
        save_ack = 1;
        #20;
        save_ack = 0;

        #500 $finish;
    end
endmodule