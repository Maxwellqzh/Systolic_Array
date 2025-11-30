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
    
    // --- 控制信号 (由外部 Controller 提供) ---
    input data_flow,     // 1: WS Mode, 0: OS Mode
    input load,          // WS Weight Loading
    input drain,         // OS Result Draining
    
    // --- 数据输入 ---
    // A (Left Input): 每一行一个 8-bit 数据
    input signed [ROWS*DATA_WIDTH-1:0] A,

    // B (Top Input): 每一列一个 8-bit 数据
    input signed [COLS*DATA_WIDTH-1:0] B,

    // --- 数据输出 ---
    // C (Bottom Output): 每一列一个 16-bit 输出
    // 注意：结果是从底部像流水线一样流出来的，不再是整个矩阵并行输出
    output signed [COLS*2*DATA_WIDTH-1:0] C_out,
    
    // 调试/级联用：最右侧的 A 输出 (可选)
    output signed [ROWS*DATA_WIDTH-1:0] A_pass_out
);

    // =========================================================
    // 1. 内部连线定义 (Interconnects)
    // =========================================================
    // 水平连线 (Horizontal Wires): 传递 A
    // 尺寸: [ROWS] 行 x [COLS+1] 列 (包含最左输入和最右输出)
    wire signed [DATA_WIDTH-1:0] w_hor [0:ROWS-1][0:COLS];

    // 垂直连线 (Vertical Wires): 传递 B / Partial Sum / Result
    // 尺寸: [ROWS+1] 行 x [COLS] 列 (包含最顶输入和最底输出)
    // 注意位宽是 2*DATA_WIDTH (16-bit)
    wire signed [2*DATA_WIDTH-1:0] w_ver [0:ROWS][0:COLS-1];

    // =========================================================
    // 2. 边界输入处理 (Boundary Inputs)
    // =========================================================
    
    genvar i, j;
    generate
        // --- 左侧输入 A ---
        for (i = 0; i < ROWS; i = i + 1) begin : A_Input_Map
            assign w_hor[i][0] = A[((i+1)*DATA_WIDTH)-1 -: DATA_WIDTH];
        end

        // --- 顶部输入 B / Partial Sum ---
        for (j = 0; j < COLS; j = j + 1) begin : B_Input_Map
            wire signed [DATA_WIDTH-1:0] b_curr_col;
            assign b_curr_col = B[((j+1)*DATA_WIDTH)-1 -: DATA_WIDTH];

            // 逻辑选择：
            // Case 1: WS计算模式 (data_flow=1, load=0) -> 输入必须是 0 (部分和初始值)
            // Case 2: 其他情况 (WS加载 / OS模式) -> 输入是 B (扩展到16位)
            // 注意符号扩展 (Sign Extension)
            
            assign w_ver[0][j] = (data_flow && !load) ? 
                                 {(2*DATA_WIDTH){1'b0}} :  // WS计算: 喂0
                                 {{DATA_WIDTH{b_curr_col[DATA_WIDTH-1]}}, b_curr_col}; // 其他: 喂B (符号扩展)
        end
    endgenerate

    // =========================================================
    // 3. PE 阵列生成 (Array Instantiation)
    // =========================================================
    generate
        for (i = 0; i < ROWS; i = i + 1) begin : Row_Gen
            for (j = 0; j < COLS; j = j + 1) begin : Col_Gen
                
                PE_Core #(
                    .DATA_WIDTH(DATA_WIDTH)
                ) u_pe (
                    .clk(clk),
                    .rst_n(rst_n),
                    
                    // 控制信号广播
                    .data_flow(data_flow),
                    .load(load),
                    .drain(drain),
                    
                    // 数据连接
                    .left (w_hor[i][j]),       // 来自左边
                    .up   (w_ver[i][j]),       // 来自上面
                    .right(w_hor[i][j+1]),     // 传给右边
                    .down (w_ver[i+1][j])      // 传给下面
                );
                
            end
        end
    endgenerate

    // =========================================================
    // 4. 边界输出处理 (Boundary Outputs)
    // =========================================================
    generate
        // --- 底部输出 (Result / Drain) ---
        // 取出 w_ver 的最后一行
        for (j = 0; j < COLS; j = j + 1) begin : C_Output_Map
            assign C_out[((j+1)*2*DATA_WIDTH)-1 -: 2*DATA_WIDTH] = w_ver[ROWS][j];
        end

        // --- 右侧输出 (A透传，通常用于调试或级联) ---
        for (i = 0; i < ROWS; i = i + 1) begin : A_Pass_Map
            assign A_pass_out[((i+1)*DATA_WIDTH)-1 -: DATA_WIDTH] = w_hor[i][COLS];
        end
    endgenerate

endmodule