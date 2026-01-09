// File         : pe_neuron.v
// Description  : Processing Element (Neuron) module

// sum_reg is on clock edge
// sig_out and tanh_out is combinational
// y_out and y_final_reg is clocked
// So for a single pass, it needs 1 clock (on any edge)


`include "tanh_lut.v"
`include "sigmoid_lut.v"

module pe_neuron #(
    parameter DATA_WIDTH = 32
) (
    input wire clk,
    input wire rst,
    input signed [DATA_WIDTH-1:0] x1, x2, x3, x4,
    input signed [DATA_WIDTH-1:0] w1, w2, w3, w4,
    input signed [DATA_WIDTH-1:0] bias,
    input wire pe_accumulate,
    input wire signed [DATA_WIDTH-1:0] partial_sum_in,
    input wire [1:0] act_sel,
    output signed [DATA_WIDTH-1:0] y_out
);

    // --- STAGE 1: Multiplication (Clocked) ---
    // Similar to neuronOp p1_reg
    reg signed [DATA_WIDTH-1:0] p1_reg, p2_reg, p3_reg, p4_reg;
    
    // Multipliers (Combinational part)
    wire signed [2*DATA_WIDTH-1:0] p1_long = x1 * w1;
    wire signed [2*DATA_WIDTH-1:0] p2_long = x2 * w2;
    wire signed [2*DATA_WIDTH-1:0] p3_long = x3 * w3;
    wire signed [2*DATA_WIDTH-1:0] p4_long = x4 * w4;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            p1_reg <= 0; p2_reg <= 0; p3_reg <= 0; p4_reg <= 0;
        end else begin
            // Shift down to Q16.16 immediately and register
            p1_reg <= p1_long >>> 16;
            p2_reg <= p2_long >>> 16;
            p3_reg <= p3_long >>> 16;
            p4_reg <= p4_long >>> 16;
        end
    end

    // --- STAGE 2: Summation (Clocked) ---
    // Similar to neuronOp y_int_reg
    reg signed [DATA_WIDTH-1:0] sum_reg;
    reg [1:0] act_sel_d1, act_sel_d2; // Delay activation select signal to match pipeline
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            sum_reg <= 0;
            act_sel_d1 <= 0;
        end else begin
            if (pe_accumulate)
                sum_reg <= p1_reg + p2_reg + p3_reg + p4_reg + bias + partial_sum_in;
            else
                sum_reg <= p1_reg + p2_reg + p3_reg + p4_reg + bias;
            
            // Pipeline the control signal too!
            act_sel_d1 <= act_sel; 
        end
    end

    // --- STAGE 3: Activation / LUT (Clocked Output) ---
    wire signed [DATA_WIDTH-1:0] tanh_out, sig_out;
    reg signed [DATA_WIDTH-1:0] y_final_reg;

    tanh_lut u_tanh (.z_in(sum_reg), .a_tanh(tanh_out));
    sigmoid_lut u_sig (.z_in(sum_reg), .a_sigmoid(sig_out));

    always @(posedge clk or negedge rst) begin
        if (!rst) y_final_reg <= 0;
        else begin
            case (act_sel_d1) // Use the delayed control signal
                2'd0: y_final_reg <= tanh_out;
                2'd1: y_final_reg <= sig_out;
                default: y_final_reg <= sum_reg;
            endcase
        end
    end

    assign y_out = y_final_reg;

endmodule