`timescale 1ns / 1ps

module tb_Systolic_input_controller;

    // 参数定义
    parameter DATA_WIDTH = 8;
    parameter ROWS = 4;
    parameter COLS = 4;
    parameter CLK_PERIOD = 10;

    // 信号定义
    reg clk;
    reg rst_n;
    reg enable;
    reg signed [DATA_WIDTH*ROWS-1:0] A;
    reg signed [DATA_WIDTH*COLS-1:0] B;
    wire signed [DATA_WIDTH*ROWS-1:0] A_out;
    wire signed [DATA_WIDTH*COLS-1:0] B_out;
    wire valid;

    // 输入输出数组变量（方便查看）
    reg [DATA_WIDTH-1:0] A_in_array [0:ROWS-1];
    reg [DATA_WIDTH-1:0] B_in_array [0:COLS-1];
    reg [DATA_WIDTH-1:0] A_out_array [0:ROWS-1];
    reg [DATA_WIDTH-1:0] B_out_array [0:COLS-1];

    // 临时数组变量
    reg [DATA_WIDTH-1:0] temp_A [0:ROWS-1];
    reg [DATA_WIDTH-1:0] temp_B [0:COLS-1];

    // 实例化被测模块
    Systolic_input_controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .ROWS(ROWS),
        .COLS(COLS)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .A(A),
        .B(B),
        .A_out(A_out),
        .B_out(B_out),
        .valid(valid)
    );

    // 时钟生成
    always #(CLK_PERIOD/2) clk = ~clk;

    // 任务：将输出向量转换为数组
    task update_output_arrays;
        integer i;
        begin
            for (i = 0; i < ROWS; i = i + 1) begin
                A_out_array[i] = A_out[((i+1)*DATA_WIDTH)-1 -: DATA_WIDTH];
            end
            for (i = 0; i < COLS; i = i + 1) begin
                B_out_array[i] = B_out[((i+1)*DATA_WIDTH)-1 -: DATA_WIDTH];
            end
        end
    endtask

    // 任务：设置输入数据
    task set_input_data_A;
        input [DATA_WIDTH-1:0] a0, a1, a2, a3;
        integer i;
        begin
            temp_A[0] = a0;
            temp_A[1] = a1;
            temp_A[2] = a2;
            temp_A[3] = a3;
            
            for (i = 0; i < ROWS; i = i + 1) begin
                A_in_array[i] = temp_A[i];
                A[((i+1)*DATA_WIDTH)-1 -: DATA_WIDTH] = temp_A[i];
            end
        end
    endtask

    task set_input_data_B;
        input [DATA_WIDTH-1:0] b0, b1, b2, b3;
        integer i;
        begin
            temp_B[0] = b0;
            temp_B[1] = b1;
            temp_B[2] = b2;
            temp_B[3] = b3;
            
            for (i = 0; i < COLS; i = i + 1) begin
                B_in_array[i] = temp_B[i];
                B[((i+1)*DATA_WIDTH)-1 -: DATA_WIDTH] = temp_B[i];
            end
        end
    endtask

    // 任务：显示输入输出数组
    task display_arrays;
        integer i;
        begin
            $write("输入: A_in_array = [");
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
            
            $write("输出: A_out_array = [");
            for (i = 0; i < ROWS; i = i + 1) begin
                $write("%0d", A_out_array[i]);
                if (i < ROWS-1) $write(", ");
            end
            $write("]");
            
            $write("  B_out_array = [");
            for (i = 0; i < COLS; i = i + 1) begin
                $write("%0d", B_out_array[i]);
                if (i < COLS-1) $write(", ");
            end
            $write("]");
            
            $display("  valid = %0d", valid);
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
            A_out_array[i] = 0;
            temp_A[i] = 0;
        end
        for (integer i = 0; i < COLS; i = i + 1) begin
            B_in_array[i] = 0;
            B_out_array[i] = 0;
            temp_B[i] = 0;
        end

        // 复位
        #(CLK_PERIOD * 2);
        rst_n = 1;
        #(CLK_PERIOD);

        $display("=== Starting Test ===");
        $display("Testing enable high for 4 cycles, input different A, B data each cycle");

        // 阶段1: enable拉高4个周期，每个周期输入不同数据
        $display("\n--- Phase 1: enable high for 4 cycles, input different data ---");
        enable = 1;
        
        // 周期1: 输入第一组数据
        set_input_data_A(1, 2, 3, 4);
        set_input_data_B(5, 6, 7, 8);
        #(CLK_PERIOD);
        update_output_arrays();
        $display("Cycle 1:");
        display_arrays();
        
        // 周期2: 输入第二组数据
        set_input_data_A(10, 20, 30, 40);
        set_input_data_B(50, 60, 70, 80);
        #(CLK_PERIOD);
        update_output_arrays();
        $display("Cycle 2:");
        display_arrays();
        
        // 周期3: 输入第三组数据
        set_input_data_A(100, 200, 300, 400);
        set_input_data_B(500, 600, 700, 800);
        #(CLK_PERIOD);
        update_output_arrays();
        $display("Cycle 3:");
        display_arrays();
        
        // 周期4: 输入第四组数据
        set_input_data_A(11, 22, 33, 44);
        set_input_data_B(55, 66, 77, 88);
        #(CLK_PERIOD);
        update_output_arrays();
        $display("Cycle 4:");
        display_arrays();

        // 阶段2: enable拉低3个周期，观察移位效果
        $display("\n--- Phase 2: enable low for 3 cycles, observe shifting ---");
        enable = 0;
        
        // 输入清零
        set_input_data_A(0, 0, 0, 0);
        set_input_data_B(0, 0, 0, 0);
        
        #(CLK_PERIOD);
        update_output_arrays();
        $display("Cycle 5:");
        display_arrays();
        
        #(CLK_PERIOD);
        update_output_arrays();
        $display("Cycle 6:");
        display_arrays();
        
        #(CLK_PERIOD);
        update_output_arrays();
        $display("Cycle 7:");
        display_arrays();

        $display("\n=== Test Finished ===");
        #(CLK_PERIOD * 2);
        $finish;
    end

    // 波形记录
    initial begin
        $dumpfile("tb_Systolic_input_controller.vcd");
        $dumpvars(0, tb_Systolic_input_controller);
    end

endmodule