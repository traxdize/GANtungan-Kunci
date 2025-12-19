`timescale 1ns/1ps
module tb_mac_pe_dbg();
  parameter DATA_WIDTH = 16;
  parameter ACC_WIDTH = 40;
  parameter FRAC = 8;

  reg clk = 0;
  reg rst = 1;

  reg signed [DATA_WIDTH-1:0] in_val;
  reg signed [DATA_WIDTH-1:0] weight_in;
  reg load_weight;
  reg signed [ACC_WIDTH-1:0] acc_in_reg;
  wire signed [ACC_WIDTH-1:0] acc_out;
  reg finalize;
  reg signed [DATA_WIDTH-1:0] bias_in;
  wire signed [DATA_WIDTH-1:0] a_out;
  wire a_valid;

  mac_pe_act_dbg #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH), .FRAC(FRAC)) dut (
    .clk(clk), .rst(rst),
    .in_val(in_val),
    .weight_in(weight_in), .load_weight(load_weight),
    .acc_out(acc_out),
    .finalize(finalize), .bias_in(bias_in),
    .act_sel(1'b0),
    .a_out(a_out), .a_valid(a_valid)
  );

  always #5 clk = ~clk;

  always @(posedge clk) begin
    if (rst) acc_in_reg <= 0;
    else acc_in_reg <= acc_out;
  end

  initial begin
    rst = 1; in_val = 0; weight_in = 0; load_weight = 0; finalize = 0; bias_in = 0;
    #20; rst = 0;

    // load weight 5, then use input 13; load weight 3, then use input -4; finalize
    in_val = 0; weight_in = 16'sd5; load_weight = 1; bias_in = 16'sd0; #10; load_weight = 0;
    in_val = 16'sd13; #10;
    in_val = 0; weight_in = 16'sd3; load_weight = 1; #10; load_weight = 0;
    in_val = -16'sd4; #10;
    in_val = 0; finalize = 1; #10; finalize = 0;

    #20 $finish;
  end
endmodule
