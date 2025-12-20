// Debug variant of mac_pe_act: prints internal multiply/accumulator/finalize signals
module mac_pe_act_dbg #(
  parameter DATA_WIDTH = 16,
  parameter ACC_WIDTH = 40,
  parameter FRAC = 8
) (
  input  wire clk,
  input  wire rst,
  input  wire signed [DATA_WIDTH-1:0] in_val,
  input  wire signed [DATA_WIDTH-1:0] weight_in,
  input  wire load_weight,
  input  wire clear_acc,
  output reg  signed [ACC_WIDTH-1:0] acc_out,
  input  wire finalize,
  input  wire signed [DATA_WIDTH-1:0] bias_in,
  input  wire act_sel,
  output wire signed [DATA_WIDTH-1:0] a_out,
  output wire a_valid
);

  reg signed [DATA_WIDTH-1:0] weight_reg;
  reg signed [ACC_WIDTH-1:0] acc_reg;
  reg signed [ACC_WIDTH-1:0] shifted;
  reg signed [ACC_WIDTH-1:0] biased;

  wire signed [2*DATA_WIDTH-1:0] prod_wide;
  assign prod_wide = $signed(in_val) * $signed(weight_reg);

  reg signed [DATA_WIDTH-1:0] z_raw_reg;
  reg z_valid_reg;
  wire signed [DATA_WIDTH-1:0] z_raw = z_raw_reg;
  wire z_valid = z_valid_reg;

  always @(posedge clk or posedge rst) begin
    if (rst) weight_reg <= 0;
    else if (load_weight) begin
      weight_reg <= weight_in;
      $display("[MAC_DBG] load_weight -> weight_reg = %0d", $signed(weight_in));
    end
  end

  always @(posedge clk or posedge rst) begin
    if (rst) acc_reg <= 0;
    else if (finalize) acc_reg <= acc_reg;
    else acc_reg <= acc_reg + prod_wide;
    acc_out <= acc_reg;
    $display("[MAC_DBG] in=%0d weight=%0d prod=%0d acc_reg_before=%0d -> acc_out=%0d", $signed(in_val), $signed(weight_reg), $signed(prod_wide), $signed(acc_reg - prod_wide), $signed(acc_out));
  end

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      z_raw_reg <= 0;
      z_valid_reg <= 0;
      shifted <= 0;
      biased <= 0;
    end else begin
      if (finalize) begin
        shifted <= acc_reg >>> FRAC;
        biased <= shifted + $signed(bias_in);
        z_raw_reg <= biased[DATA_WIDTH-1:0];
        z_valid_reg <= 1;
        $display("[MAC_DBG] finalize: acc_reg=%0d shifted=%0d bias=%0d z_raw=%0d", $signed(acc_reg), $signed(shifted), $signed(bias_in), $signed(biased[DATA_WIDTH-1:0]));
      end else begin
        z_valid_reg <= 0;
      end
    end
  end

  wire [DATA_WIDTH-1:0] a_sig;
  wire [DATA_WIDTH-1:0] a_tanh;
  sigmoid_lut sigmoid_inst (.z_q1_7_8(z_raw), .a_sigmoid(a_sig));
  tanh_lut    tanh_inst    (.z_q1_7_8(z_raw), .a_tanh(a_tanh));

  assign a_out = (act_sel == 1'b0) ? $signed(a_tanh) : $signed(a_sig);
  assign a_valid = z_valid;

endmodule
