// File         : ram_block.v
// Description  : Dual-port RAM with zero-initialization and debug save task.
// Standard     : Verilog-2001

module ram_block (
    input  clk,
    input  we_a,
    input  [11:0] addr_a,
    input  signed [31:0] data_in_a,
    input  [11:0] addr_b,
    output reg signed [31:0] data_out_b
);

    reg [31:0] mem [0:4095];
    integer i;

    // Zero-initialize memory to prevent X propagation
    initial begin
        for (i = 0; i < 4096; i = i + 1) begin
            mem[i] = 32'd0;
        end
    end

    always @(posedge clk) begin
        if (we_a) mem[addr_a] <= data_in_a;
        data_out_b <= mem[addr_b];
    end

    // synthesis translate_off
    // Debug task to save memory contents to a file
    task save_to_file;
        input [256*8-1:0] filename;
        input integer num_words;
        integer fd, j;
        begin
            fd = $fopen(filename, "w");
            if (fd != 0) begin
                for (j = 0; j < num_words; j = j + 1) begin
                    $fdisplay(fd, "%08h", mem[j]);
                end
                $fclose(fd);
            end
        end
    endtask
    // synthesis translate_on

endmodule