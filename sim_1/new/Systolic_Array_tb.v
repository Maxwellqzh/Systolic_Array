`timescale 1ns / 1ps

module tb_Systolic_Array;

    // 参数定义
    parameter DATA_WIDTH = 8;
    parameter ROWS = 8;
    parameter COLS = 8;
    parameter CLK_PERIOD = 10;

    // 信号定义
    reg clk;
    reg rst_n;
    reg enable;
    reg signed [DATA_WIDTH*ROWS-1:0] A;
    reg signed [DATA_WIDTH*COLS-1:0] B;
    wire valid;
    wire signed [2*DATA_WIDTH*ROWS*COLS-1:0] C;

    // 输入输出数组变量（方便查看）
    reg [DATA_WIDTH-1:0] A_in_array [0:ROWS-1];
    reg [DATA_WIDTH-1:0] B_in_array [0:COLS-1];
    reg [2*DATA_WIDTH-1:0] C_out_array [0:ROWS-1][0:COLS-1];

    // 临时数组变量
    reg [DATA_WIDTH-1:0] temp_A [0:ROWS-1];
    reg [DATA_WIDTH-1:0] temp_B [0:COLS-1];

    // 实例化被测模块
    Systolic_Array #(
        .DATA_WIDTH(DATA_WIDTH),
        .ROWS(ROWS),
        .COLS(COLS)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .A(A),
        .B(B),
        .valid(valid),
        .C(C)
    );

    // 时钟生成
    always #(CLK_PERIOD/2) clk = ~clk;

    // 任务：将输出向量转换为二维数组
    task update_output_arrays;
        integer i, j;
        begin
            for (i = 0; i < ROWS; i = i + 1) begin
                for (j = 0; j < COLS; j = j + 1) begin
                    C_out_array[i][j] = C[((i*COLS + j + 1)*2*DATA_WIDTH)-1 -: 2*DATA_WIDTH];
                end
            end
        end
    endtask

    // 任务：设置输入数据A
    task set_input_data_A;
        input [DATA_WIDTH-1:0] a0, a1, a2, a3, a4, a5, a6, a7;
        integer i;
        begin
            temp_A[0] = a0;
            temp_A[1] = a1;
            temp_A[2] = a2;
            temp_A[3] = a3;
            temp_A[4] = a4;
            temp_A[5] = a5;
            temp_A[6] = a6;
            temp_A[7] = a7;
            
            for (i = 0; i < ROWS; i = i + 1) begin
                A_in_array[i] = temp_A[i];
                A[((i+1)*DATA_WIDTH)-1 -: DATA_WIDTH] = temp_A[i];
            end
        end
    endtask

    // 任务：设置输入数据B
    task set_input_data_B;
        input [DATA_WIDTH-1:0] b0, b1, b2, b3, b4, b5, b6, b7;
        integer i;
        begin
            temp_B[0] = b0;
            temp_B[1] = b1;
            temp_B[2] = b2;
            temp_B[3] = b3;
            temp_B[4] = b4;
            temp_B[5] = b5;
            temp_B[6] = b6;
            temp_B[7] = b7;
            
            for (i = 0; i < COLS; i = i + 1) begin
                B_in_array[i] = temp_B[i];
                B[((i+1)*DATA_WIDTH)-1 -: DATA_WIDTH] = temp_B[i];
            end
        end
    endtask

    // 任务：显示输入数组
    task display_input_arrays;
        integer i;
        begin
            $write("Input: A_in_array = [");
            for (i = 0; i < ROWS; i = i + 1) begin
                $write("%0d", A_in_array[i]);
                if (i < ROWS-1) $write(", ");
            end
            $write("]");
            
            $write("  B_in_array = [");
            for (i = 0; i < COLS; i = i + 1) begin
                $write("%0d", B_in_array[i]);
                if (i < COLS-1) $write(", ");
            end
            $write("]\n");
        end
    endtask

    // 任务：显示输出矩阵（简化显示，只显示部分信息）
    task display_output_matrix;
        integer i, j;
        begin
            $display("Output matrix C (valid = %0d):", valid);
            // 只显示前4行前4列，避免输出太长
            for (i = 0; i < 4; i = i + 1) begin
                $write("    [");
                for (j = 0; j < 4; j = j + 1) begin
                    $write("%0d", C_out_array[i][j]);
                    if (j < 3) $write(", ");
                end
                $write(" ...]");
                if (i < 3) $write(",");
                $display("");
            end
            $display("    [ ... ]");
        end
    endtask

    // 主测试
    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        enable = 0;
        A = 0;
        B = 0;

        // 初始化数组
        for (integer i = 0; i < ROWS; i = i + 1) begin
            A_in_array[i] = 0;
            temp_A[i] = 0;
            for (integer j = 0; j < COLS; j = j + 1) begin
                C_out_array[i][j] = 0;
            end
        end
        for (integer i = 0; i < COLS; i = i + 1) begin
            B_in_array[i] = 0;
            temp_B[i] = 0;
        end

        // 复位
        #(CLK_PERIOD * 2);
        rst_n = 1;
        #(CLK_PERIOD);

        $display("=== Starting 8x8 Systolic_Array Test ===");
        $display("Testing enable high for 8 cycles, input different A, B data each cycle");

        // 阶段1: enable拉高8个周期，每个周期输入不同数据
        $display("\n--- Phase 1: enable high for 8 cycles, input different data ---");
        enable = 1;
        
        // 周期1-8: 输入不同的数据
        set_input_data_A(1, 2, 3, 4, 5, 6, 7, 8);
        set_input_data_B(1, 2, 3, 4, 5, 6, 7, 8);
        #(CLK_PERIOD);
        update_output_arrays();
        $display("Cycle 1:");
        display_input_arrays();
        display_output_matrix();
        
        set_input_data_A(1, 2, 3, 4, 5, 6, 7, 8);
        set_input_data_B(1, 2, 3, 4, 5, 6, 7, 8);
        #(CLK_PERIOD);
        update_output_arrays();
        $display("Cycle 2:");
        display_input_arrays();
        display_output_matrix();
        
        set_input_data_A(1, 2, 3, 4, 5, 6, 7, 8);
        set_input_data_B(1, 2, 3, 4, 5, 6, 7, 8);
        #(CLK_PERIOD);
        update_output_arrays();
        $display("Cycle 3:");
        display_input_arrays();
        display_output_matrix();
        
        set_input_data_A(1, 2, 3, 4, 5, 6, 7, 8);
        set_input_data_B(1, 2, 3, 4, 5, 6, 7, 8);;
        #(CLK_PERIOD);
        update_output_arrays();
        $display("Cycle 4:");
        display_input_arrays();
        display_output_matrix();
        
        set_input_data_A(1, 2, 3, 4, 5, 6, 7, 8);
        set_input_data_B(1, 2, 3, 4, 5, 6, 7, 8);
        #(CLK_PERIOD);
        update_output_arrays();
        $display("Cycle 5:");
        display_input_arrays();
        display_output_matrix();
        
        set_input_data_A(1, 2, 3, 4, 5, 6, 7, 8);
        set_input_data_B(1, 2, 3, 4, 5, 6, 7, 8);
        #(CLK_PERIOD);
        update_output_arrays();
        $display("Cycle 6:");
        display_input_arrays();
        display_output_matrix();
        
        set_input_data_A(1, 2, 3, 4, 5, 6, 7, 8);
        set_input_data_B(1, 2, 3, 4, 5, 6, 7, 8);
        #(CLK_PERIOD);
        update_output_arrays();
        $display("Cycle 7:");
        display_input_arrays();
        display_output_matrix();
        
        set_input_data_A(1, 2, 3, 4, 5, 6, 7, 8);
        set_input_data_B(1, 2, 3, 4, 5, 6, 7, 8);
        #(CLK_PERIOD);
        update_output_arrays();
        $display("Cycle 8:");
        display_input_arrays();
        display_output_matrix();

        // 阶段2: enable拉低多个周期，等待计算结果
        $display("\n--- Phase 2: enable low, waiting for calculation results ---");
        enable = 0;
        
        // 输入清零
        set_input_data_A(0, 0, 0, 0, 0, 0, 0, 0);
        set_input_data_B(0, 0, 0, 0, 0, 0, 0, 0);
        
        // 观察多个周期的输出变化（8x8阵列需要更多周期）
        repeat(20) begin
            #(CLK_PERIOD);
            update_output_arrays();
            $display("Cycle %0d:", $time/CLK_PERIOD);
            display_input_arrays();
            display_output_matrix();
        end

        $display("\n=== 8x8 Test Finished ===");
        #(CLK_PERIOD * 2);
        $finish;
    end

    // 波形记录
    initial begin
        $dumpfile("tb_Systolic_Array_8x8.vcd");
        $dumpvars(0, tb_Systolic_Array);
    end

endmodule