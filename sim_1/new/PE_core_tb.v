`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/24 15:59:57
// Design Name: 
// Module Name: PE_core_tb
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


module PE_core_tb;
    reg clk;
    reg rst_n;
    reg signed [7:0] a_curr;
    reg signed [7:0] b_curr;

    wire signed [7:0] a_last;
    wire signed [7:0] b_last;
    wire signed [15:0] data_out;

    // ============================
    // DUT 实例
    // ============================
    PE_core u_PE_core(
        .clk(clk),
        .rst_n(rst_n),
        .a_curr(a_curr),
        .b_curr(b_curr),
        .a_last(a_last),
        .b_last(b_last),
        .data_out(data_out)
    );

    // ============================
    // 1. 时钟：10ns周期
    // ============================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;   // 100MHz
    end
    
    initial begin
        // 初始值
        rst_n  = 1;
        a_curr = 0;
        b_curr = 0;

        #20;
        rst_n = 0;
        
        #20;
        rst_n = 1;

        // ============================
        // 输入激励
        // ============================

        // Cycle 1
        @(posedge clk);
        a_curr <= 8'sd3;
        b_curr <= 8'sd4;

        // Cycle 2
        @(posedge clk);
        a_curr <= -8'sd5;
        b_curr <= 8'sd2;

        // Cycle 3
        @(posedge clk);
        a_curr <= 8'sd7;
        b_curr <= -8'sd3;

        // Cycle 4
        @(posedge clk);
        a_curr <= 8'sd1;
        b_curr <= 8'sd1;

        // 保持 5 cycle 观察累加行为
        repeat(5) @(posedge clk);

    end
endmodule
