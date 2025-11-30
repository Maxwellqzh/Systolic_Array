// Engineer:      Zhenhang Qin
// Create Date:   2025/11/24
// Design Name:   controller
// Module Name:   controller
// Description:   用于重排输入信号，将并行输入的A和B信号分时输入
// input:
//      clk: 时钟信号
//      rst_n: 复位信号
//      enable: 输入使能信号,当最后一组数据输入后，拉低
//      data_flow: 数据流选择信号，0为OS，1为WS
//      A: 输入的A值,长度为ROWS*DATA_WIDTH
//      B: 输入的B值,长度为COLS*DATA_WIDTH
// output:
//      valid: enable的延迟信号，用于控制PE_array的输入使能信号
//      A_out: 重排后的A信号,长度为ROWS*DATA_WIDTH
//      B_out: 重排后的B信号,长度为COLS*DATA_WIDTH

module Systolic_Input_Controller #(
    parameter DATA_WIDTH = 8,
    parameter ROWS = 8,
    parameter COLS = 8
)(
    input clk,
    input rst_n, 
    input enable,
    input load,          // 高电平：权重加载模式
    input data_flow,     // 1: WS模式, 0: OS模式
    
    // 展平的输入向量
    input signed [DATA_WIDTH*ROWS-1:0] A,  
    input signed [DATA_WIDTH*COLS-1:0] B,  
    
    // 处理后的输出向量
    output signed [DATA_WIDTH*ROWS-1:0] A_out,
    output signed [DATA_WIDTH*COLS-1:0] B_out,
    
    output reg valid
);

    // ============================================================
    // 1. Valid 信号控制
    // ============================================================
    // 简单的打一拍逻辑，实际应用中可能需要根据流水线深度调整
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            valid <= 0;
        else 
            valid <= enable;
    end

    // ============================================================
    // 2. A 通道打拍逻辑 (Always Skewed)
    // ============================================================
    // A 无论在 WS 还是 OS 模式下，作为计算输入，都需要进行对角线排列。
    // 第 i 行需要延迟 i 个周期。
    // 注意：所谓的“转置”由外部数据源决定（OS送矩阵的行，WS送矩阵的列），
    // 控制器只负责保证第 i 个端口的数据比第 i-1 个端口晚 1 个周期到达。
    
    genvar i;
    generate
        for (i = 0; i < ROWS; i = i + 1) begin : GEN_A_SKEW
            // 定义第 i 行的输入和输出切片
            wire signed [DATA_WIDTH-1:0] a_slice_in;
            wire signed [DATA_WIDTH-1:0] a_slice_delayed;
            
            assign a_slice_in = A[((i+1)*DATA_WIDTH)-1 -: DATA_WIDTH];
            
            // 实例化延迟单元 (Shift Register)
            // 第 0 行延迟 0 拍 (或1拍，取决于系统设计，这里设为相对延迟)
            // 这里为了对齐，我们假设第 i 行使用 i 个寄存器级联
            Delay_Line #(.WIDTH(DATA_WIDTH), .DEPTH(i + 1)) u_delay_a (
                .clk(clk), .rst_n(rst_n), .in_data(a_slice_in), .out_data(a_slice_delayed)
            );
            assign A_out[((i+1)*DATA_WIDTH)-1 -: DATA_WIDTH] = a_slice_delayed;
        end
    endgenerate

    // ============================================================
    // 3. B 通道打拍逻辑 (Conditional Skew)
    // ============================================================
    // OS 模式：B 是流动输入，需要打拍 (Col j 延迟 j)。
    // WS 模式 & Load=1：B 是权重，需要快速并行灌入，不需要打拍 (Bypass)。
    
    genvar j;
    generate
        for (j = 0; j < COLS; j = j + 1) begin : GEN_B_SKEW
            wire signed [DATA_WIDTH-1:0] b_slice_in;
            wire signed [DATA_WIDTH-1:0] b_slice_delayed;
            wire signed [DATA_WIDTH-1:0] b_final_out;
            
            assign b_slice_in = B[((j+1)*DATA_WIDTH)-1 -: DATA_WIDTH];

            // 同样的延迟逻辑：Col j 延迟 j+1 周期
            Delay_Line #(.WIDTH(DATA_WIDTH), .DEPTH(j + 1)) u_delay_b (
                .clk(clk), .rst_n(rst_n), .in_data(b_slice_in), .out_data(b_slice_delayed)
            );

            // --- 核心修改：Load 模式旁路逻辑 ---
            // 如果是 WS 模式 (data_flow=1) 且正在加载 (load=1)，
            // 直接透传输入 (b_slice_in)，否则使用延迟后的数据 (b_slice_delayed)。
            // 这里通常会对 b_slice_in 打一级寄存器以保证时序收敛，即 Delay=1 vs Delay=j+1
            
            reg signed [DATA_WIDTH-1:0] b_bypass_reg;
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) b_bypass_reg <= 0;
                else       b_bypass_reg <= b_slice_in; // 统一的基础延迟
            end
            
            // 选择逻辑
            assign b_final_out = (data_flow && load) ? b_bypass_reg : b_slice_delayed;
            
            assign B_out[((j+1)*DATA_WIDTH)-1 -: DATA_WIDTH] = b_final_out;
        end
    endgenerate

endmodule


// ============================================================
// 辅助模块：通用移位寄存器 (Delay Line)
// ============================================================
module Delay_Line #(
    parameter WIDTH = 8,
    parameter DEPTH = 1
)(
    input clk,
    input rst_n,
    input [WIDTH-1:0] in_data,
    output [WIDTH-1:0] out_data
);
    // 展平的寄存器数组
    reg [WIDTH-1:0] shift_reg [0:DEPTH-1];
    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < DEPTH; k = k + 1) begin
                shift_reg[k] <= 0;
            end
        end else begin
            shift_reg[0] <= in_data;
            for (k = 1; k < DEPTH; k = k + 1) begin
                shift_reg[k] <= shift_reg[k-1];
            end
        end
    end

    assign out_data = shift_reg[DEPTH-1];

endmodule