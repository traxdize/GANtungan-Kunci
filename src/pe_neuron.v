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

  // ReLu activation function
  assign y = (sum > 0) ? sum[WIDTH-1:0] : 0;


endmodule
