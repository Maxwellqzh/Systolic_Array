// Engineer:      Zhenhang Qin
// Create Date:   2025/11/27
// Design Name:   Systolic Array
// Module Name:   Systolic_Array
// Description:   一个可切换OS和WS的Systolic Array，内置8*8的PE阵列
// input:
//      clk: 时钟信号
//      rst_n: 复位信号
//      enable: 输入使能信号,当最后一组数据输入后，拉低
//      load: 权重加载使能信号,当load为1时，将B作为权重输入
//      data_flow: 数据流选择信号，0为OS，1为WS
//      drain: 结果抽取使能信号,当drain为1时，将结果抽取出来
//      A: 输入的A值,长度为ROWS*DATA_WIDTH
//      B: 输入的B值,长度为COLS*DATA_WIDTH
// output:
//      C: 输出结果，长度为ROWS*COLS*DATA_WIDTH

module Systolic_Array
#(parameter DATA_WIDTH = 8, parameter ROWS = 8, parameter COLS = 8)
(
    input clk,
    input rst_n,
    input enable,
    input data_flow,
    input load,
    input drain,
    input signed [DATA_WIDTH*ROWS-1:0] A,
    input signed [DATA_WIDTH*COLS-1:0] B,
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
        .data_flow(data_flow),
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