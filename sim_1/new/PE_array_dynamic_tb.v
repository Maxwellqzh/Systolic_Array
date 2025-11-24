`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/24 19:41:18
// Design Name: 
// Module Name: PE_array_dynamic_tb
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


module PE_array_dynamic_tb;
    parameter ROW_len = 4;   // A 的行数、C 的行数
    parameter COL_len = 5;   // B 的列数、C 的列数
    parameter K       = 4;   // A 的列数、B 的行数
    parameter DW      = 8;   // 位宽
    parameter ACCW    = 16;   // 位宽
    
    reg clk;
    reg rst_n;

    // 输入 A（左侧）
    reg  signed [DW-1:0] a_in [0:ROW_len-1];
    // 输入 B（顶部）
    reg  signed [DW-1:0] b_in [0:COL_len-1];

    // 展开为总线
    wire signed [ROW_len*DW-1:0] a_bus;
    wire signed [COL_len*DW-1:0] b_bus;

    genvar gi;
    generate
        // A 输入展开
        for (gi = 0; gi < ROW_len; gi = gi + 1) begin : GEN_A_BUS
            assign a_bus[(gi+1)*DW-1 -: DW] = a_in[gi];
        end
    
        // B 输入展开
        for (gi = 0; gi < COL_len; gi = gi + 1) begin : GEN_B_BUS
            assign b_bus[(gi+1)*DW-1 -: DW] = b_in[gi];
        end
    endgenerate
    // 输出 C（4×5，共 20 个 16-bit）
    wire signed [ROW_len*COL_len*ACCW-1:0] c_bus;
    integer i, j;
    integer idx;
    // ====================================
    // 实例化 4×5 脉动阵列
    // ====================================
    PE_array_dynamic #(
        .ROW_len(ROW_len),
        .COL_len(COL_len),
        .DW(DW),
        .ACCW(ACCW)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .a_bus(a_bus),
        .b_bus(b_bus),
        .c_bus(c_bus)
    );

    // ====================================
    // 时钟
    // ====================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ====================================
    // 定义 A(4×4) 与 B(4×5)
    // ====================================
    reg signed [7:0] A[0:ROW_len-1][0:K-1];  // 4×4
    reg signed [7:0] B[0:K-1][0:COL_len-1];  // 4×5

    integer i,j,t,idx;

    // ====================================
    // 数据初始化
    // ====================================
    initial begin
    // A (4×4)
        A[0][0]=1;  A[0][1]=2;  A[0][2]=3;  A[0][3]=4;  
        A[1][0]=5;  A[1][1]=6;  A[1][2]=7;  A[1][3]=8;  
        A[2][0]=9; A[2][1]=10; A[2][2]=11; A[2][3]=12; 
        A[3][0]=13; A[3][1]=14; A[3][2]=15; A[3][3]=16; 
    
        // B (4×5)
        B[0][0]=1;  B[0][1]=2;  B[0][2]=3;  B[0][3]=4;  B[0][4]=5;
        B[1][0]=6;  B[1][1]=7;  B[1][2]=8;  B[1][3]=9;  B[1][4]=10;
        B[2][0]=11; B[2][1]=12; B[2][2]=13; B[2][3]=14; B[2][4]=15;
        B[3][0]=16; B[3][1]=17; B[3][2]=18; B[3][3]=19; B[3][4]=20;
    end

    // ====================================
    // 脉动阵列输入公式
    // A(i,k) 在 t=i+k 时进入
    // B(k,j) 在 t=j+k 时进入
    // ====================================
    initial begin
        rst_n = 1;
        // 初始化 A_in / B_in
        for (i=0;i<ROW_len;i=i+1) a_in[i] = 0;
        for (j=0;j<COL_len;j=j+1) b_in[j] = 0;

        #20 rst_n = 0;
        #20 rst_n = 1;

        // ===== Data Feeding Phase =====
        for (t = 0; t < (K + ROW_len + COL_len + 5); t = t + 1) begin
            @(posedge clk);

            // ------- A 输入：左 → 右 -------
            for (i=0;i<ROW_len;i=i+1) begin
                if (t >= i && (t-i) < K)
                    a_in[i] <= A[i][t-i];
                else
                    a_in[i] <= 0;
            end

            // ------- B 输入：上 → 下 -------
            for (j=0;j<COL_len;j=j+1) begin
                if (t >= j && (t-j) < K)
                    b_in[j] <= B[t-j][j];
                else
                    b_in[j] <= 0;
            end
        end

        // 等待阵列完全流水结束
        repeat(20) @(posedge clk);

        // 打印输出矩阵
        $display("\n======= C = A × B (4×5) 输出 =======\n");

        for (i = 0; i < ROW_len; i = i + 1) begin
            $write("Row %0d: ", i);
            for (j = 0; j < COL_len; j = j + 1) begin
                
                idx = (i*COL_len + j)*ACCW;
                $write("%0d ", c_bus[idx + ACCW - 1 -: ACCW]);
            end
            $write("\n");
        end

        $finish;
    end

endmodule