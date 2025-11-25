// Engineer:      Zhenhang Qin
// Create Date:   2025/11/24
// Design Name:   controller
// Module Name:   controller
// Description:   用于重排输入信号，将并行输入的A和B信号分时输入
// input:
//      clk: 时钟信号
//      rst_n: 复位信号
//      enable: 输入使能信号,当最后一组数据输入后，拉低
//      A: 输入的A值,长度为ROWS*DATA_WIDTH
//      B: 输入的B值,长度为COLS*DATA_WIDTH
// output:
//      valid: enable的延迟信号，用于控制PE_array的输入使能信号

module Systolic_Input_Controller #(
    parameter DATA_WIDTH = 8,
    parameter ROWS = 8,
    parameter COLS = 8
)(
    input clk,
    input rst_n, 
    input enable,
    input signed [DATA_WIDTH*ROWS-1:0] A,  // 展平的A向量
    input signed [DATA_WIDTH*COLS-1:0] B,  // 展平的B向量
    output signed [DATA_WIDTH*ROWS-1:0] A_out,
    output signed [DATA_WIDTH*COLS-1:0] B_out,
    output reg valid
);

    // A的移位寄存器组（每行一个）
    reg signed [DATA_WIDTH-1:0] A_shift [0:ROWS-1][0:ROWS-1];
    // B的移位寄存器组（每列一个）  
    reg signed [DATA_WIDTH-1:0] B_shift [0:COLS-1][0:COLS-1];
    
    integer i, j, k, m;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid <= 0;
        end
        else if (enable) begin
            valid <= 1;
        end
        else begin
            valid <= 0;
        end
    end
    
    // 初始化移位寄存器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < ROWS; i = i + 1) begin
                for (j = 0; j < ROWS; j = j + 1) begin
                    A_shift[i][j] <= 0;
                end
            end
            for (i = 0; i < COLS; i = i + 1) begin
                for (j = 0; j < COLS; j = j + 1) begin
                    B_shift[i][j] <= 0;
                end
            end
        end
        else begin
            // A向量移位逻辑
            for (i = 0; i < ROWS; i = i + 1) begin
                for (j = 0; j < i; j = j + 1) begin
                    A_shift[i][j] <= A_shift[i][j+1];
                end
                // 纯Verilog的部分选择语法
                A_shift[i][i] <= A[((i+1)*DATA_WIDTH)-1 -: DATA_WIDTH];
            end
            
            // B向量移位逻辑
            for (i = 0; i < COLS; i = i + 1) begin
                for (j = 0; j < i; j = j + 1) begin
                    B_shift[i][j] <= B_shift[i][j+1];
                end
                // 纯Verilog的部分选择语法
                B_shift[i][i] <= B[((i+1)*DATA_WIDTH)-1 -: DATA_WIDTH];
            end
        end
    end
    
    // 输出当前对角线数据
    genvar gi, gj;
    generate
        for (gi = 0; gi < ROWS; gi = gi + 1) begin : A_OUTPUT_GEN
            assign A_out[((gi+1)*DATA_WIDTH)-1 -: DATA_WIDTH] = A_shift[gi][0];
        end
        for (gj = 0; gj < COLS; gj = gj + 1) begin : B_OUTPUT_GEN
            assign B_out[((gj+1)*DATA_WIDTH)-1 -: DATA_WIDTH] = B_shift[gj][0];
        end
    endgenerate

endmodule