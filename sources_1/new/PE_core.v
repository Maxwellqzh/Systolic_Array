`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Create Date:   2025/11/24
// Design Name:   PE_core
// Module Name:   PE_core
// Description:   用于计算两个8位有符号数相乘，将输入传递给下一个单元，并累加结果
// input:
//      clk: 时钟信号
//      rst_n: 复位信号
//      a_curr: 当前输入的A值
//      b_curr: 当前输入的B值
// output:
//      a_last: 传递给下一个单元的A值
//      b_last: 传递给下一个单元的B值
//      data_out: 累加结果
//

module PE_Core
#(parameter DATA_WIDTH = 8)
(
    input clk,rst_n,
    input signed [DATA_WIDTH-1:0] a_curr,
    input signed [DATA_WIDTH-1:0] b_curr,
    output reg signed [DATA_WIDTH-1:0] a_last,
    output reg signed [DATA_WIDTH-1:0] b_last,
    output reg signed [2*DATA_WIDTH-1:0] data_out
    );
    wire signed [2*DATA_WIDTH-1:0] data_tmp;
    wire rst;
    assign rst = !rst_n;
    always@(posedge clk or negedge rst_n)
        begin
            if(!rst_n)
                begin
                    a_last<='d0;
                    b_last<='d0;
                    data_out<='d0;
                end
            else
                begin
                    a_last<=a_curr;
                    b_last<=b_curr;
                    data_out<=data_out+data_tmp;
                end
        end

    // multiplier u_multiplier(
    //     .clk(clk),
    //     .CE(1),
    //     .SCLR(rst),
    //     .A(a_curr),
    //     .B(b_curr),
    //     .P (data_tmp)
    // );
    multiplier u_multiplier(
        .clk(clk),
        .CE(1),
        .SCLR(rst),
        .A(a_curr),
        .B(b_curr),
        .P(data_tmp)
    );
endmodule

module multiplier
#(parameter DATA_WIDTH = 8)
(
    input clk,CE,SCLR,
    input signed [DATA_WIDTH-1:0] A,
    input signed [DATA_WIDTH-1:0] B,
    output reg   [2*DATA_WIDTH-1:0] P
);
    always@(posedge clk or posedge SCLR)
        begin
            if(SCLR)
                P<=0;
            else
            if(CE)
                P<=A*B;
            else
                P<=P;
        end
endmodule
