module Systolic_Array
 #(parameter DATA_WIDTH = 8, parameter ROWS = 8, parameter COLS = 8)
(
    input clk,
    input rst,
    input [DATA_WIDTH-1:0] data_in,
    output [DATA_WIDTH-1:0] data_out
);
    wire [DATA_WIDTH-1:0] pe_out[ROWS-1:0][COLS-1:0];
    wire [DATA_WIDTH-1:0] pe_in[ROWS-1:0][COLS-1:0];
    wire [DATA_WIDTH-1:0] pe_in[ROWS-1:0][COLS-1:0];

    

endmodule