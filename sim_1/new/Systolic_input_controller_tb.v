`timescale 1ns / 1ps

module tb_Systolic_Input_Controller;

    // =========================
    // 1. 参数定义
    // =========================
    parameter DATA_WIDTH = 8;
    parameter ROWS = 4; // 为了方便观察波形，我们用 4x4 的规模
    parameter COLS = 4;

    // =========================
    // 2. 信号声明
    // =========================
    reg clk;
    reg rst_n;
    reg enable;
    reg load;
    reg data_flow;

    // 展平的输入/输出向量
    reg  signed [DATA_WIDTH*ROWS-1:0] A_in;
    reg  signed [DATA_WIDTH*COLS-1:0] B_in;
    wire signed [DATA_WIDTH*ROWS-1:0] A_out;
    wire signed [DATA_WIDTH*COLS-1:0] B_out;
    wire valid;

    // 辅助变量：用于生成测试数据
    integer i, j;

    // =========================
    // 3. 实例化 DUT (Device Under Test)
    // =========================
    Systolic_Input_Controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .ROWS(ROWS),
        .COLS(COLS)
    ) u_controller (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .load(load),
        .data_flow(data_flow),
        .A(A_in),
        .B(B_in),
        .A_out(A_out),
        .B_out(B_out),
        .valid(valid)
    );

    // =========================
    // 4. 时钟生成 (10ns 周期)
    // =========================
    always #5 clk = ~clk;

    // =========================
    // 5. 测试流程
    // =========================
    initial begin
        // --- 初始化 ---
        clk = 0;
        rst_n = 0;
        enable = 0;
        load = 0;
        data_flow = 0;
        A_in = 0;
        B_in = 0;

        // 释放复位
        #20 rst_n = 1;

        // ============================================================
        // Case 1: WS 模式 - 权重加载测试 (Weight Load Bypass Check)
        // 目标：验证 B 通道是否“对齐”输出，没有阶梯延迟
        // ============================================================
        $display("\n=== Test Case 1: WS Mode Weight Loading (Should act as Bypass) ===");
        @(posedge clk);
        enable <= 1;
        data_flow <= 1; // WS Mode
        load <= 1;      // Loading Phase

        // 构造输入数据：
        // A 输入 0 (加载权重时不关心A)
        // B 输入固定的权重值: Col0=0x10, Col1=0x20, Col2=0x30, Col3=0x40
        for (j=0; j<COLS; j=j+1) begin
            B_in[((j+1)*DATA_WIDTH)-1 -: DATA_WIDTH] = (j+1) * 16; 
        end
        
        @(posedge clk); // 等待数据打入
        #1; // 稍微延迟以便观察输出
        
        // 检查输出：理论上只需要1个时钟周期（基础延迟），所有列应该同时有数据
        display_output_status("WS Load (T+1)");

        @(posedge clk); 
        #1;
        display_output_status("WS Load (T+2)");


        // ============================================================
        // Case 2: OS 模式 - 计算流测试 (OS Streaming Skew Check)
        // 目标：验证 A 和 B 通道是否都呈现“阶梯状”延迟
        // ============================================================
        $display("\n=== Test Case 2: OS Mode Streaming (Should act as Staircase) ===");
        
        // 重置一下状态
        rst_n = 0; #10 rst_n = 1;

        @(posedge clk);
        enable <= 1;
        data_flow <= 0; // OS Mode
        load <= 0;      // Compute Phase

        // 持续喂入数据流
        // 每个周期输入都在变，方便观察流动
        fork 
            begin
                // 模拟发送 6 个周期的数据
                for (i=1; i<=6; i=i+1) begin
                    // A 输入: Row0=01, Row1=01... (每行都给相同值，方便看列延迟)
                    // B 输入: Col0=01, Col1=01...
                    for (j=0; j<ROWS; j=j+1) A_in[((j+1)*DATA_WIDTH)-1 -: DATA_WIDTH] = i;
                    for (j=0; j<COLS; j=j+1) B_in[((j+1)*DATA_WIDTH)-1 -: DATA_WIDTH] = i;
                    
                    @(posedge clk); // 等待下一个时钟
                    #1; // 采样点
                    display_output_status($sformatf("OS Stream Input=%0d", i));
                end
                // 停止输入
                A_in = 0;
                B_in = 0;
                #50;
            end
        join

        $display("\n=== Test Finished ===");
        $finish;
    end

    // =========================
    // 6. 辅助显示任务
    // =========================
    // 用于打印当前时刻所有端口的输出值，模拟波形图
    task display_output_status;
        input [127:0] tag;
        integer k;
        reg [DATA_WIDTH-1:0] val_a, val_b;
        begin
            $write("Time %0t | %s | ", $time, tag);
            
            $write("A_Out: [ ");
            for (k=0; k<ROWS; k=k+1) begin
                val_a = A_out[((k+1)*DATA_WIDTH)-1 -: DATA_WIDTH];
                $write("%2h ", val_a);
            end
            $write("] (Row0->Row3) | ");

            $write("B_Out: [ ");
            for (k=0; k<COLS; k=k+1) begin
                val_b = B_out[((k+1)*DATA_WIDTH)-1 -: DATA_WIDTH];
                $write("%2h ", val_b);
            end
            $write("] (Col0->Col3)\n");
        end
    endtask

endmodule