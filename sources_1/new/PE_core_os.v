`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: hzn
// 
// Create Date: 2025/11/28 15:01:59
// Design Name: 
// Module Name: PE_core_os
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


module PE_core_os(
    input clk,rst_n,
    input compute_en,
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
            if(!rst_n)begin
                    a_last <= 0;
                    b_last <= 0;
            end
            else if (compute_en) begin
                // flow
                a_last <= a_curr;
                b_last <= b_curr;
            end
            else begin
                // reset
                a_last <= 0;
                b_last <= 0;
            end
        end
    always@(posedge clk or negedge rst_n)
        begin
            if(!rst_n) data_out <= 0;
            else if (compute_en) data_out <= data_out+data_tmp;  // flow
            else data_out <= 0;  // reset
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
