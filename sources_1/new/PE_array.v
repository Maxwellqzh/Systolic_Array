// Engineer:      Zhenhang Qin
// Create Date:   2025/11/24
// Design Name:   PE_array
// Module Name:   PE_array
// Description:   用于计算两个矩阵相乘，结果按行输出
// input:
//      clk: 时钟信号
//      rst_n: 复位信号
//      en: 输入使能信号,当最后一组数据的第一个元素输入后，使能拉低
//      A: 输入的A值,长度为ROWS*DATA_WIDTH
//      B: 输入的B值,长度为COLS*DATA_WIDTH
//      C: 输出结果,按行输出
//      valid: 输出有效信号，计算完成后拉高一个时钟周期

`timescale 1ns / 1ps


module PE_Array #(
    parameter DATA_WIDTH = 8,
    parameter ROWS = 8,
    parameter COLS = 8
)(
    input clk,
    input rst_n,
    input en,  // 输入使能信号,当最后一组数据输入后，使能拉低

    // 左侧输入 A（按行输入），展平为一维向量
    // 排列方式：A[0], A[1], ..., A[ROWS-1]
    input signed [ROWS*DATA_WIDTH-1:0] A,

    // 顶部输入 B（按列输入），展平为一维向量  
    // 排列方式：B[0], B[1], ..., B[COLS-1]
    input signed [COLS*DATA_WIDTH-1:0] B,

    // 输出矩阵 C（累加），展平为一维向量
    // 排列方式：C[0][0], C[0][1], ..., C[0][COLS-1], C[1][0], ...
    output signed [ROWS*COLS*2*DATA_WIDTH-1:0] C,
    
    output valid  // 输出有效信号
);

// 内部连接信号
wire signed [DATA_WIDTH-1:0] A_2d [0:ROWS-1];
wire signed [DATA_WIDTH-1:0] B_2d [0:COLS-1];
wire signed [2*DATA_WIDTH-1:0] C_2d [0:ROWS-1][0:COLS-1];

// PE之间的连接信号
wire signed [DATA_WIDTH-1:0] a_horizontal [0:ROWS-1][0:COLS];  // 水平方向传播的A数据
wire signed [DATA_WIDTH-1:0] b_vertical   [0:ROWS][0:COLS-1];  // 垂直方向传播的B数据

// 流水线控制信号
reg [ROWS+COLS-1:0] pipeline_valid;  // 流水线有效标志
wire computation_done;  // 计算完成信号

// 计算流水线深度（数据从输入到输出需要的时间）
localparam PIPELINE_DEPTH = ROWS + COLS - 1;

// 将输入A展平到二维数组
genvar i, j;
generate
    for (i = 0; i < ROWS; i = i + 1) begin : A_reshape
        assign A_2d[i] = A[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH];
    end
    
    // 将输入B展平到二维数组  
    for (i = 0; i < COLS; i = i + 1) begin : B_reshape
        assign B_2d[i] = B[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH];
    end
    
    // 连接输入到PE阵列边界
    for (i = 0; i < ROWS; i = i + 1) begin : A_input_conn
        assign a_horizontal[i][0] = A_2d[i];  // 每行的第一个PE接收外部A输入
    end
    
    for (j = 0; j < COLS; j = j + 1) begin : B_input_conn
        assign b_vertical[0][j] = B_2d[j];    // 每列的第一个PE接收外部B输入
    end
    
    // 生成PE阵列
    for (i = 0; i < ROWS; i = i + 1) begin : row_gen
        for (j = 0; j < COLS; j = j + 1) begin : col_gen
            PE_Core #(
                .DATA_WIDTH(DATA_WIDTH)
            ) PE_inst (
                .clk(clk),
                .rst_n(rst_n),
                .a_curr(a_horizontal[i][j]),      // 当前PE的A输入
                .b_curr(b_vertical[i][j]),        // 当前PE的B输入
                .a_last(a_horizontal[i][j+1]),    // A输出到右侧PE
                .b_last(b_vertical[i+1][j]),      // B输出到下方PE
                .data_out(C_2d[i][j])             // 计算结果输出
            );
            
        end
    end
    
    // 将输出C_2d展平到一维输出向量
    for (i = 0; i < ROWS; i = i + 1) begin : C_output_row
        for (j = 0; j < COLS; j = j + 1) begin : C_output_col
            assign C[((i*COLS + j) + 1) * (2*DATA_WIDTH) - 1 : 
                     (i*COLS + j) * (2*DATA_WIDTH)] = C_2d[i][j];
        end
    end
    
endgenerate

// 输出有效信号：当计算完成且输入使能已经拉低（表示这是最后一组数据）
reg en_delayed;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        en_delayed <= 0;
    end else begin
        en_delayed <= en;
    end
end

// 检测en的下降沿（从高到低）
wire en_falling_edge = en_delayed && !en;

// 流水线有效标志控制
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pipeline_valid <= 0;
    end else begin
        // 移位寄存器，跟踪数据在流水线中的位置
        pipeline_valid <= {pipeline_valid[ROWS+COLS-2:0], en_falling_edge};
    end
end

// 计算完成判断：当最后一个PE的数据有效时，整个计算完成
assign computation_done = pipeline_valid[PIPELINE_DEPTH-1];


// 有效信号生成：当检测到en下降沿后，等待计算完成
reg valid_generation;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_generation <= 0;
    end else if (en_falling_edge) begin
        // 检测到en下降沿，开始等待计算完成
        valid_generation <= 1;
    end else if (computation_done && valid_generation) begin
        // 计算完成，清除有效生成标志
        valid_generation <= 0;
    end
end

// 最终有效信号输出
assign valid = computation_done && valid_generation;

endmodule