`timescale 1ns / 1ps

module PE_Array #(
    parameter DATA_WIDTH = 8,
    parameter ROWS = 8,
    parameter COLS = 8
)(
    input clk,
    input rst_n,
    input en,            // 外部输入使能
    
    // --- 控制信号 ---
    input data_flow,     // 1: WS Mode, 0: OS Mode
    input load,          // WS Weight Loading
    input acc_en,        // [新增] 累加使能: 1=累加C_acc, 0=从0开始计算 (仅在WS计算模式有效)
    
    // --- 数据输入 ---
    input signed [ROWS*DATA_WIDTH-1:0] A,
    input signed [COLS*DATA_WIDTH-1:0] B,
    input signed [COLS*2*DATA_WIDTH-1:0] C_acc,

    // --- 数据输出 ---
    output valid,        // 由内部 Controller 产生
    output signed [COLS*2*DATA_WIDTH-1:0] C_out, // 原始的斜向输出 (Raw Skewed Output)
    output signed [ROWS*DATA_WIDTH-1:0] A_pass_out
);

    // =========================================================
    // 1. 内部连线定义
    // =========================================================
    wire signed [DATA_WIDTH-1:0] w_hor [0:ROWS-1][0:COLS];
    wire signed [2*DATA_WIDTH-1:0] w_ver [0:ROWS][0:COLS-1];    
    // 内部控制信号
    wire internal_drain; 
    reg [COLS*2*DATA_WIDTH-1:0] C_acc_1d;

    always@(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            C_acc_1d <= 0;
        end else begin
            C_acc_1d <= C_acc;
        end
    end

    // =========================================================
    // 2. 实例化状态控制器
    // =========================================================
    PE_Status_Controller #(
        .ROWS(ROWS),
        .COLS(COLS)
    ) u_controller (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .data_flow(data_flow),
        .drain_out(internal_drain), // OS模式使用的 Drain 信号
        .valid_out(valid)           // 全局输出有效信号
    );

    // =========================================================
    // 3. 边界输入处理 (含 Loopback Mux)
    // =========================================================
    genvar i, j;
    generate
        // --- 左侧输入 A ---
        for (i = 0; i < ROWS; i = i + 1) begin : A_Input_Map
            assign w_hor[i][0] = A[((i+1)*DATA_WIDTH)-1 -: DATA_WIDTH];
        end

        // --- 顶部输入 B / C_acc / 0 ---
        for (j = 0; j < COLS; j = j + 1) begin : B_Input_Map
            // 提取当前列的 B 输入 (8-bit)
            wire signed [DATA_WIDTH-1:0] b_curr_col;
            assign b_curr_col = B[((j+1)*DATA_WIDTH)-1 -: DATA_WIDTH];
            
            // 提取当前列的 Loopback 输入 (16-bit)
            wire signed [2*DATA_WIDTH-1:0] acc_curr_col;
            assign acc_curr_col = C_acc_1d[((j+1)*2*DATA_WIDTH)-1 -: 2*DATA_WIDTH];

            // 扩展 B 到 16-bit (符号扩展)
            wire signed [2*DATA_WIDTH-1:0] b_extended;
            assign b_extended = {{DATA_WIDTH{b_curr_col[DATA_WIDTH-1]}}, b_curr_col};

            // 核心选择逻辑：
            // 1. WS Load: 必须喂权重 (B)
            // 2. OS Mode: 必须喂数据流 (B)
            // 3. WS Compute & Acc_En: 喂 Loopback 数据 (C_acc_1d)
            // 4. WS Compute & !Acc_En: 喂 0 (开始新一轮计算)
            
            assign w_ver[0][j] = (data_flow && load) ? b_extended :   // WS: 加载权重
                                 (!data_flow)        ? b_extended :   // OS: 数据流
                                 (acc_en)            ? acc_curr_col : // WS: 累加旧结果
                                                       {(2*DATA_WIDTH){1'b0}}; // WS: 新计算 (输入0)
        end
    endgenerate

    // =========================================================
    // 4. PE 阵列生成
    // =========================================================
    generate
        for (i = 0; i < ROWS; i = i + 1) begin : Row_Gen
            for (j = 0; j < COLS; j = j + 1) begin : Col_Gen
                PE_Core #(
                    .DATA_WIDTH(DATA_WIDTH)
                ) u_pe (
                    .clk(clk),
                    .rst_n(rst_n),
                    .data_flow(data_flow),
                    .load(load),
                    .drain(internal_drain), 
                    
                    .left (w_hor[i][j]),       
                    .up   (w_ver[i][j]),       
                    .right(w_hor[i][j+1]),     
                    .down (w_ver[i+1][j])      
                );
            end
        end
    endgenerate

    // =========================================================
    // 5. 边界输出处理 
    // =========================================================
    // 直接输出阵列底部的数据，保持斜向时序，以便外部 Loopback 直接对接
    generate
        for (j = 0; j < COLS; j = j + 1) begin : Final_Output_Map
            assign C_out[((j+1)*2*DATA_WIDTH)-1 -: 2*DATA_WIDTH] = w_ver[ROWS][j];
        end

        // A 透传输出
        for (i = 0; i < ROWS; i = i + 1) begin : A_Pass_Map
            assign A_pass_out[((i+1)*DATA_WIDTH)-1 -: DATA_WIDTH] = w_hor[i][COLS];
        end
    endgenerate

endmodule