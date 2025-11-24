module PE
 #(parameter DATA_WIDTH = 8)
(
    input clk,
    input rst,
    input [DATA_WIDTH-1:0] up,
    input [DATA_WIDTH-1:0] left,
    output [DATA_WIDTH-1:0] down,
    output [DATA_WIDTH-1:0] right,
    output [2*DATA_WIDTH-1:0] sum_out
);
    wire [2*DATA_WIDTH-1:0] mul_out;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            right <= 0;
            down <= 0;
            sum_out <= 0;
        end else begin
            down <= up;
            right <= left;
            sum_out <= sum_out + mul_out;
        end
    end

    multiplier #(DATA_WIDTH) multiplier_inst(
        .a(up),
        .b(left),
        .out(mul_out)
    );
endmodule

module multiplier #(parameter DATA_WIDTH = 8)
(
    input [DATA_WIDTH-1:0] a,
    input [DATA_WIDTH-1:0] b,
    output [2*DATA_WIDTH-1:0] out
);
    assign out = a * b;
endmodule