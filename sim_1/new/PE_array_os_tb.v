`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: hzn
// 
// Create Date: 2025/11/28 16:09:09
// Design Name: 
// Module Name: PE_array_os_tb
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


module PE_array_os_tb;
    parameter ROW_len = 4;   // A 的行数
    parameter COL_len = 5;   // B 的列数
    parameter K       = 4;   // A 的列数 / B 的行数
    parameter DW      = 8;
    parameter ACCW    = 16;

    reg clk;
    reg rst_n;
    reg compute_en;   // 新增
    reg read_en_in;     // 新增（阵列计算完成）

    reg  signed [DW-1:0] a_in [0:ROW_len-1];
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
    
    // 输出矩阵 C（4×5）
    wire signed [COL_len*ACCW-1:0] c_bus;

    // 实例化 DUT
    PE_array_os #(
        .ROW_len(ROW_len),
        .COL_len(COL_len),
        .DW(DW),
        .ACCW(ACCW)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .compute_en(compute_en),  
        .read_en_in(read_en_in),        
        .a_bus(a_bus),
        .b_bus(b_bus),
        .c_bus(c_bus)
    );

    // 时钟
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ============================
    // 定义两个输入矩阵 A1,B1,A2,B2
    // ============================
    reg signed [DW-1:0] A1[0:ROW_len-1][0:K-1];
    reg signed [DW-1:0] B1[0:K-1][0:COL_len-1];

    reg signed [DW-1:0] A2[0:ROW_len-1][0:K-1];
    reg signed [DW-1:0] B2[0:K-1][0:COL_len-1]; 

    integer i,j,t,idx;

    // 数据初始化
    initial begin
        // A1
        A1[0][0]=1; A1[0][1]=2; A1[0][2]=3; A1[0][3]=4;
        A1[1][0]=5; A1[1][1]=6; A1[1][2]=7; A1[1][3]=8;
        A1[2][0]=9; A1[2][1]=10;A1[2][2]=11;A1[2][3]=12;
        A1[3][0]=13;A1[3][1]=14;A1[3][2]=15;A1[3][3]=16;

        // B1
        B1[0][0]=1; B1[0][1]=2; B1[0][2]=3; B1[0][3]=4; B1[0][4]=5;
        B1[1][0]=6; B1[1][1]=7; B1[1][2]=8; B1[1][3]=9; B1[1][4]=10;
        B1[2][0]=11;B1[2][1]=12;B1[2][2]=13;B1[2][3]=14;B1[2][4]=15;
        B1[3][0]=16;B1[3][1]=17;B1[3][2]=18;B1[3][3]=19;B1[3][4]=20;

        // A2
        A2[0][0]=1; A2[0][1]=1; A2[0][2]=1; A2[0][3]=1;
        A2[1][0]=2; A2[1][1]=2; A2[1][2]=2; A2[1][3]=2;
        A2[2][0]=3; A2[2][1]=3; A2[2][2]=3; A2[2][3]=3;
        A2[3][0]=4; A2[3][1]=4; A2[3][2]=4; A2[3][3]=4;

        // B2
        B2[0][0]=1; B2[0][1]=0; B2[0][2]=0; B2[0][3]=0; B2[0][4]=0;
        B2[1][0]=0; B2[1][1]=1; B2[1][2]=0; B2[1][3]=0; B2[1][4]=0;
        B2[2][0]=0; B2[2][1]=0; B2[2][2]=1; B2[2][3]=0; B2[2][4]=0;
        B2[3][0]=0; B2[3][1]=0; B2[3][2]=0; B2[3][3]=1; B2[3][4]=0;
    end
    
     // -------------------------------
    // Feed Matrix Task
    // -------------------------------
    task feed_matrix;
        input [31:0] sel;
        integer i,j,t;
        begin
            for (t = 0; t < (K + ROW_len + COL_len + 5); t = t + 1) begin
                @(posedge clk);

                for (i=0;i<ROW_len;i=i+1)
                    if (t >= i && (t-i) < K)
                        a_in[i] <= (sel==1) ? A1[i][t-i] : A2[i][t-i];
                    else
                        a_in[i] <= 0;

                for (j=0;j<COL_len;j=j+1)
                    if (t >= j && (t-j) < K)
                        b_in[j] <= (sel==1) ? B1[t-j][j] : B2[t-j][j];
                    else
                        b_in[j] <= 0;
            end
        end
    endtask

    // -------------------------------
    // Print Result Task
    // -------------------------------
    task print_one_row;
        integer j, idx;
        begin
            for (j = 0; j < COL_len; j = j + 1) begin
                idx = j*ACCW;
                $write("%0d ", c_bus[idx + ACCW - 1 -: ACCW]);
            end
            $write("\n");
        end
    endtask

    // -------------------------------
    // Main Test Flow
    // -------------------------------
    initial begin
        rst_n = 1;
        compute_en = 0;
        read_en_in = 0;

        for (i=0;i<ROW_len;i=i+1) a_in[i]=0;
        for (j=0;j<COL_len;j=j+1) b_in[j]=0;

        #20 rst_n = 0;
        #20 rst_n = 1;

        // -------- 第一次计算 --------
        $display("\n===== Start First MatMul =====\n");
        compute_en = 1;

        feed_matrix(1);

        # 140;
        @(posedge clk);
        $display("\n===== First Result =====\n");
        read_en_in = 1;
        for(i=0;i<ROW_len;i=i+1) begin
            @(posedge clk);
            $write("Row %0d: ", ROW_len-1-i);
            print_one_row();
        end
        read_en_in = 0;

        // -------- 清空阵列 --------
//        #20 compute_en = 0;
//        #20;

        // -------- 第二次计算 --------
        $display("\n===== Start Second MatMul =====\n");
        compute_en = 1;

        feed_matrix(2);

        # 140;
        @(posedge clk);
        $display("\n===== Second Result =====\n");
        read_en_in = 1;
        for(i=0;i<ROW_len;i=i+1) begin
            @(posedge clk);
            $write("Row %0d: ", ROW_len-1-i);
            print_one_row();
        end
        read_en_in = 0;

        $finish;
    end

endmodule