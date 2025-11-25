`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/24 16:37:08
// Design Name: 
// Module Name: PE_array_tb
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


module PE_array_tb;
    reg clk;
    reg rst_n;

    // 输入端口（左侧 A，顶部 B）
    reg signed [7:0] a0, a1, a2;
    reg signed [7:0] b0, b1, b2;

    // 输出矩阵 C
    wire signed [15:0] c00, c01, c02;
    wire signed [15:0] c10, c11, c12;
    wire signed [15:0] c20, c21, c22;

    // ================================
    // DUT 实例
    // ================================
    PE_array u_PE_array(
        .clk(clk),
        .rst_n(rst_n),
        .a0(a0), .a1(a1), .a2(a2),
        .b0(b0), .b1(b1), .b2(b2),
        .c00(c00), .c01(c01), .c02(c02),
        .c10(c10), .c11(c11), .c12(c12),
        .c20(c20), .c21(c21), .c22(c22)
    );

    // ================================
    // 时钟 10ns（100 MHz）
    // ================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // =====================================
    // 定义 A 和 B（3x3）
    // =====================================
    // 你可以在这里换成你想要的矩阵
    reg signed [7:0] A [0:2][0:2];
    reg signed [7:0] B [0:2][0:2];

    integer i, k;

    // ================================
    // 主测试流程
    // ================================
    initial begin
        // 定义矩阵 A
        A[0][0]=1;  A[0][1]=2;  A[0][2]=3;
        A[1][0]=4;  A[1][1]=5;  A[1][2]=6;
        A[2][0]=7;  A[2][1]=8;  A[2][2]=9;

        // 定义矩阵 B
        B[0][0]=9;  B[0][1]=6;  B[0][2]=3;
        B[1][0]=8;  B[1][1]=5;  B[1][2]=2;
        B[2][0]=7;  B[2][1]=4;  B[2][2]=1;
        // 初始状态
        rst_n = 1;
        a0 = 0; a1 = 0; a2 = 0;
        b0 = 0; b1 = 0; b2 = 0;

        #20;
        rst_n = 0;
        
        // 释放复位
        #20;
        rst_n = 1;

        // ================
        // Feeding phase
        // ================
        @(posedge clk);  a0 <= A[0][0];                                  b0 <= B[0][0];
        @(posedge clk);  a0 <= A[0][1];  a1 <= A[1][0];                  b0 <= B[1][0];  b1 <= B[0][1];
        @(posedge clk);  a0 <= A[0][2];  a1 <= A[1][1];  a2 <= A[2][0];  b0 <= B[2][0];  b1 <= B[1][1];  b2 <= B[0][2];
        @(posedge clk);  a0 <= 0;        a1 <= A[1][2];  a2 <= A[2][1];  b0 <= 0;        b1 <= B[2][1];  b2 <= B[1][2];
        @(posedge clk);  a0 <= 0;        a1 <= 0;        a2 <= A[2][2];  b0 <= 0;        b1 <= 0;        b2 <= B[2][2];
        @(posedge clk); a0<=0; a1<=0; a2<=0;  b0<=0; b1<=0; b2<=0;
        // 再等待 10 个 cycle 让阵列跑完内部累加
        repeat(10) @(posedge clk);

        // 打印最终矩阵
        $display("---- PE Array Output Matrix ----");
        $display("%d %d %d", c00, c01, c02);
        $display("%d %d %d", c10, c11, c12);
        $display("%d %d %d", c20, c21, c22);
        $display("--------------------------------");

        $finish;
    end

endmodule
