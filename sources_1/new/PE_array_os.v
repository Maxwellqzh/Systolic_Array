`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: hzn
// 
// Create Date: 2025/11/28 15:00:30
// Design Name: 
// Module Name: PE_array_os
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


module PE_array_os#(
    parameter ROW_len    = 3, 
    parameter COL_len    = 3,
    parameter DW   = 8,   // A/B 位宽
    parameter ACCW = 16   // 累加位宽
)(
    input clk,
    input rst_n,
    input compute_en,
    input read_en_in,

    input  signed [ROW_len*DW-1:0] a_bus,
    input  signed [COL_len*DW-1:0] b_bus,
    output reg signed [COL_len*ACCW-1:0] c_bus
);
//    localparam integer LATENCY = ROW_len + ROW_len + COL_len - 1;   
    // 内部 a/b 信号与 data_out
    wire signed [DW-1:0]   a_curr [0:ROW_len-1][0:COL_len-1];
    wire signed [DW-1:0]   b_curr [0:ROW_len-1][0:COL_len-1];
    wire signed [DW-1:0]   a_last [0:ROW_len-1][0:COL_len-1];
    wire signed [DW-1:0]   b_last [0:ROW_len-1][0:COL_len-1];
    wire signed [ACCW-1:0] c_sig  [0:ROW_len-1][0:COL_len-1];

    genvar i, j;
    generate
        for (i = 0; i < ROW_len; i = i + 1) begin: ROW_GEN
            for (j = 0; j < COL_len; j = j + 1) begin: COL_GEN

                // ================
                // A 数据来源
                // ================
                if (j == 0)
                    // 第 0 列从 a_bus 输入
                    assign a_curr[i][j] = a_bus[(i+1)*DW-1 -: DW];
                else
                    // 其他列从左边 PE 得到
                    assign a_curr[i][j] = a_last[i][j-1];

                // ================
                // B 数据来源
                // ================
                if (i == 0)
                    // 第 0 行从 b_bus 输入
                    assign b_curr[i][j] = b_bus[(j+1)*DW-1 -: DW];
                else
                    // 其他行从上面 PE 得到
                    assign b_curr[i][j] = b_last[i-1][j];

                // ================
                // 实例化 PE_core
                // ================
                PE_core_os u_PE_core_os (
                    .clk     (clk),
                    .rst_n   (rst_n),
                    .compute_en(compute_en),
                    .a_curr  (a_curr[i][j]),
                    .b_curr  (b_curr[i][j]),
                    .a_last  (a_last[i][j]),
                    .b_last  (b_last[i][j]),
                    .data_out(c_sig[i][j])
                );
            end
        end
    endgenerate
    
    reg [7:0] row_ptr;
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            row_ptr <= ROW_len-1;  // 从最后一行开始
            c_bus <= 0;
        end
        else if(!read_en_in) begin
            // 读使能拉低时恢复为最后一行
            row_ptr <= ROW_len-1;
            c_bus <= 0;
        end
        else begin
            // 逐行输出该行的所有列数据
            
            for(k = 0; k < COL_len; k = k + 1) begin
                c_bus[(k+1)*ACCW-1 -: ACCW] <= c_sig[row_ptr][k];
            end
    
            // 下一拍：上一行
            if(row_ptr > 0)
                row_ptr <= row_ptr - 1;
            else
                row_ptr <= ROW_len-1;   // 输出完 0 行后回到最后一行
        end
    end
endmodule
