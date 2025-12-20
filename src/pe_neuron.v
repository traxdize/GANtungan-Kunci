// File name    : pe_neuron.v
// Author       : Vico A.C. Silalahi (13223067)
// Description  : neuron processing element for IN number input, should be used multiple times in a single layer.
//                Input is the output of all the previous nodes multiplied by the weight in w(i,j)
//                i being the previous node and j being the current node

module pe_neuron #(
    parameter IN = 4,
    parameter WIDTH = 32
) (
    input signed [IN*WIDTH-1:0] x,
    input signed [WIDTH-1:0] b,
  // Activation select: 0 = tanh, 1 = sigmoid
  input wire act_sel,
    output signed [WIDTH-1:0] y
);
  localparam SUM_WIDTH = WIDTH + $clog2(IN) + 1;

  wire signed [WIDTH-1:0] x_un[IN-1:0];
  reg signed  [SUM_WIDTH-1:0] sum;

  // Unflatten input x to x_un
  genvar i;
  generate
    for (i = 0; i < IN; i = i + 1) begin : unflatten_x
      assign x_un[i] = x[(i+1)*WIDTH-1 : i*WIDTH];
    end
  endgenerate

  // Accumulate for each input that is already weighted and also the bias for this particular node
  integer j;
  always @(*) begin
    sum = b;
    for (j = 0; j < IN; j = j + 1) begin
      sum = sum + x_un[j];
    end
  end

  // Activation: selectable between sigmoid and tanh LUTs
  // Convert lower bits of sum to Q1.7.8 16-bit input for the LUTs
  wire [15:0] z_q1_7_8 = sum[15:0];

  wire [15:0] a_sigmoid;
  wire [15:0] a_tanh;

  sigmoid_lut sigmoid_inst (
    .z_q1_7_8(z_q1_7_8),
    .a_sigmoid(a_sigmoid)
  );

  tanh_lut tanh_inst (
    .z_q1_7_8(z_q1_7_8),
    .a_tanh(a_tanh)
  );

  // Select between tanh (act_sel=0) and sigmoid (act_sel=1)
  wire [15:0] a_selected = (act_sel == 1'b0) ? a_tanh : a_sigmoid;

  // Sign-extend the 16-bit LUT output to the module output width
  assign y = {{(WIDTH-16){a_selected[15]}}, a_selected};


endmodule
