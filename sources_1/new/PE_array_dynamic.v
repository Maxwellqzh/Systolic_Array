`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/24 18:50:55
// Design Name: 
// Module Name: PE_array_dynamic
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


module PE_array_dynamic #(
    parameter ROW_len    = 3, 
    parameter COL_len    = 3,
    parameter DW   = 8,   // A/B 位宽
    parameter ACCW = 16   // 累加位宽
)(
    input clk,
    input rst_n,

     // 输入总线：左侧输入 A（ROW_len 行）
    // a_bus = {a[ROW_len-1], ..., a[1], a[0]}
    input  signed [ROW_len*DW-1:0] a_bus,

    // 输入总线：顶部输入 B（COL_len 列）
    // b_bus = {b[COL_len-1], ..., b[1], b[0]}
    input  signed [COL_len*DW-1:0] b_bus,

    // 输出 C（ROW_len × COL_len）
    // 展开为一维 c_bus
    output signed [ROW_len*COL_len*ACCW-1:0] c_bus
);

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
                PE_core u_PE_core (
                    .clk     (clk),
                    .rst_n   (rst_n),
                    .a_curr  (a_curr[i][j]),
                    .b_curr  (b_curr[i][j]),
                    .a_last  (a_last[i][j]),
                    .b_last  (b_last[i][j]),
                    .data_out(c_sig[i][j])
                );

                // ================
                // 输出 c_sig → c_bus
                // 按行展开成一维总线
                // index = (i * COL_len + j) * ACCW
                // ================
                localparam integer C_IDX = (i*COL_len + j)*ACCW;
                assign c_bus[C_IDX + ACCW - 1 : C_IDX] = c_sig[i][j];

            end
        end
    endgenerate

endmodule
