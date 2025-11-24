`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/24 16:15:07
// Design Name: 
// Module Name: PE_array
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module PE_array(
    input clk,
    input rst_n,

    // 左侧输入 A（按行输入）
    input signed [7:0] a0,  // row 0
    input signed [7:0] a1,  // row 1
    input signed [7:0] a2,  // row 2

    // 顶部输入 B（按列输入）
    input signed [7:0] b0,  // col 0
    input signed [7:0] b1,  // col 1
    input signed [7:0] b2,  // col 2

    // 输出矩阵 C（累加）
    output signed [15:0] c00, c01, c02,
    output signed [15:0] c10, c11, c12,
    output signed [15:0] c20, c21, c22
);

    // 内部级联信号
    wire signed [7:0] a01, a02;
    wire signed [7:0] a11, a12;
    wire signed [7:0] a21, a22;

    wire signed [7:0] b10, b20;
    wire signed [7:0] b11, b21;
    wire signed [7:0] b12, b22;

    // ===============================
    // 第一行：c00 → c01 → c02
    // ===============================

    PE_core P00(
        .clk(clk), .rst_n(rst_n),
        .a_curr(a0),
        .b_curr(b0),
        .a_last(a01),
        .b_last(b10),
        .data_out(c00)
    );

    PE_core P01(
        .clk(clk), .rst_n(rst_n),
        .a_curr(a01),
        .b_curr(b1),
        .a_last(a02),
        .b_last(b11),
        .data_out(c01)
    );

    PE_core P02(
        .clk(clk), .rst_n(rst_n),
        .a_curr(a02),
        .b_curr(b2),
        .a_last(/* unused */),
        .b_last(b12),
        .data_out(c02)
    );

    // ===============================
    // 第二行：c10 → c11 → c12
    // ===============================

    PE_core P10(
        .clk(clk), .rst_n(rst_n),
        .a_curr(a1),
        .b_curr(b10),
        .a_last(a11),
        .b_last(b20),
        .data_out(c10)
    );

    PE_core P11(
        .clk(clk), .rst_n(rst_n),
        .a_curr(a11),
        .b_curr(b11),
        .a_last(a12),
        .b_last(b21),
        .data_out(c11)
    );

    PE_core P12(
        .clk(clk), .rst_n(rst_n),
        .a_curr(a12),
        .b_curr(b12),
        .a_last(/* unused */),
        .b_last(b22),
        .data_out(c12)
    );

    // ===============================
    // 第三行：c20 → c21 → c22
    // ===============================

    PE_core P20(
        .clk(clk), .rst_n(rst_n),
        .a_curr(a2),
        .b_curr(b20),
        .a_last(a21),
        .b_last(/* unused */),
        .data_out(c20)
    );

    PE_core P21(
        .clk(clk), .rst_n(rst_n),
        .a_curr(a21),
        .b_curr(b21),
        .a_last(a22),
        .b_last(/* unused */),
        .data_out(c21)
    );

    PE_core P22(
        .clk(clk), .rst_n(rst_n),
        .a_curr(a22),
        .b_curr(b22),
        .a_last(/* unused */),
        .b_last(/* unused */),
        .data_out(c22)
    );

endmodule
