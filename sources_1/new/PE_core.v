`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/24 15:37:12
// Design Name: 
// Module Name: PE_core
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


module PE_core(
    input clk,rst_n,
    input signed [7:0] a_curr,
    input signed [7:0] b_curr,
    output reg signed [7:0] a_last,
    output reg signed [7:0] b_last,
    output reg signed [15:0] data_out
    );
    wire signed [15:0] data_tmp;
    wire rst;
    assign rst = !rst_n;
    always@(posedge clk or negedge rst_n)
        begin
            if(!rst_n)
                begin
                    a_last<='d0;
                    b_last<='d0;
                end
            else
                begin
                    a_last<=a_curr;
                    b_last<=b_curr;
                end
        end
    always@(posedge clk or negedge rst_n)
        begin
            if(!rst_n) data_out<='d0;
            else data_out<=data_out+data_tmp;
        end
    
    multiplier u_multiplier(
        .clk(clk),
        .CE(1),
        .SCLR(rst),
        .A(a_curr),
        .B(b_curr),
        .P (data_tmp)
    );
endmodule
