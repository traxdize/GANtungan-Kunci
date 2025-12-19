`timescale 1ns/1ps
module tb_mac_pe();
  parameter DATA_WIDTH = 16;
  parameter ACC_WIDTH = 40;
  parameter FRAC = 8;

  reg clk = 0;
  reg rst = 1;

  // DUT signals
  reg signed [DATA_WIDTH-1:0] in_val;
  reg signed [DATA_WIDTH-1:0] weight_in;
  reg load_weight;
  reg signed [ACC_WIDTH-1:0] acc_in_reg;
  wire signed [ACC_WIDTH-1:0] acc_out;
  reg finalize;
  reg signed [DATA_WIDTH-1:0] bias_in;
  wire signed [DATA_WIDTH-1:0] z_out;
  wire z_valid;

  // Instantiate DUT (MAC-PE with activation wrapper)
  wire signed [DATA_WIDTH-1:0] a_out;
  wire a_valid;
  mac_pe_act #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH), .FRAC(FRAC)) dut (
    .clk(clk), .rst(rst),
    .in_val(in_val),
    .weight_in(weight_in), .load_weight(load_weight),
    .acc_out(acc_out),
    .finalize(finalize), .bias_in(bias_in),
    .act_sel(1'b0), // 0 -> tanh (can change to 1 for sigmoid)
    .a_out(a_out), .a_valid(a_valid)
  );

  always #5 clk = ~clk;

  // feedback the previous acc_out one cycle later
  always @(posedge clk) begin
    if (rst) acc_in_reg <= 0;
    else acc_in_reg <= acc_out;
  end

  initial begin
    rst = 1; in_val = 0; weight_in = 0; load_weight = 0; finalize = 0; bias_in = 0;
    #20; rst = 0;

    // Example: compute dot([13, -4], [5, 3]) with FRAC=8 scaling
    // Sequence: load weight, then present input that uses it
    // Cycle A: load weight 5
    in_val = 0; weight_in = 16'sd5; load_weight = 1; finalize = 0; bias_in = 16'sd0;
    #10; load_weight = 0;

    // Cycle B: present in_val = 13 (uses weight 5)
    in_val = 16'sd13; weight_in = 0; load_weight = 0;
    #10;

    // Cycle C: load weight 3
    in_val = 0; weight_in = 16'sd3; load_weight = 1;
    #10; load_weight = 0;

    // Cycle D: present in_val = -4 (uses weight 3)
    in_val = -16'sd4; #10;

    // Cycle E: finalize and get activation output
    in_val = 0; finalize = 1; bias_in = 16'sd0; #10; finalize = 0;

    if (a_valid) begin
      $display("Activation output a_out (hex) = %h", a_out);
      $display("a_out signed = %0d", $signed(a_out));
      $display("a_out float ~= %f", $signed(a_out) / 256.0);
    end else begin
      $display("a_valid not asserted");
    end

    #20 $finish;
  end
endmodule
