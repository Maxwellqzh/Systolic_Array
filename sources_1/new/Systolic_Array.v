module Systolic_Array
#(parameter DATA_WIDTH = 8, parameter ROWS = 8, parameter COLS = 8)
(
    input clk,
    input rst_n,
    input enable,
    input signed [DATA_WIDTH*ROWS-1:0] A,
    input signed [DATA_WIDTH*COLS-1:0] B,
    output valid,
    output signed [2*DATA_WIDTH*ROWS*COLS-1:0] C
);
    wire signed [DATA_WIDTH*ROWS-1:0] PE_A;
    wire signed [DATA_WIDTH*COLS-1:0] PE_B;
    wire enable_PE;

    Systolic_Input_Controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .ROWS(ROWS),
        .COLS(COLS)
    )
    u_Systolic_Input_Controller
    (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .A(A),
        .B(B),
        .A_out(PE_A),
        .B_out(PE_B),
        .valid(enable_PE)
    );
    
    PE_Array#(
    .DATA_WIDTH(DATA_WIDTH),
    .ROWS(ROWS),
    .COLS(COLS)
    )u_PE_Array
    (
        .clk(clk),
        .rst_n(rst_n),
        .en(enable_PE),
        .A(PE_A),
        .B(PE_B),
        .C(C),
        .valid(valid)
    );

endmodule