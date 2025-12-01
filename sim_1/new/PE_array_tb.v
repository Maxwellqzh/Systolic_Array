`timescale 1ns / 1ps

module tb_PE_Array;

    // ==========================================
    // 1. 参数设置
    // ==========================================
    parameter DATA_WIDTH = 8;
    parameter ROWS = 4; 
    parameter COLS = 4;
    
    // 验证场景：C(4x4) = A(4x8) * B(8x4)
    // K_TOTAL = 8
    parameter K_TOTAL = 8;
    parameter K_PASS  = 4; // 仅用于 WS 分块测试，OS 测试使用 K_TOTAL

    // ==========================================
    // 2. 信号与变量
    // ==========================================
    reg clk, rst_n, en;
    reg data_flow, load, acc_en;
    
    reg signed [ROWS*DATA_WIDTH-1:0] A_flat_in;
    reg signed [COLS*DATA_WIDTH-1:0] B_flat_in;
    reg signed [COLS*2*DATA_WIDTH-1:0] C_acc_in;
    
    wire valid;
    wire signed [COLS*2*DATA_WIDTH-1:0] C_out;
    wire signed [ROWS*DATA_WIDTH-1:0] A_pass_out;

    // 存储
    reg signed [DATA_WIDTH-1:0] mat_A [0:ROWS-1][0:K_TOTAL-1];
    reg signed [DATA_WIDTH-1:0] mat_B [0:K_TOTAL-1][0:COLS-1];
    reg signed [2*DATA_WIDTH-1:0] mat_C_expected [0:ROWS-1][0:COLS-1];
    reg signed [2*DATA_WIDTH-1:0] mat_C_actual [0:ROWS-1][0:COLS-1];

    // WS Loopback FIFO
    reg signed [COLS*2*DATA_WIDTH-1:0] loopback_fifo [0:63]; 
    integer fifo_wr_ptr, fifo_rd_ptr;

    // ==========================================
    // 3. DUT 实例化
    // ==========================================
    PE_Array #(
        .DATA_WIDTH(DATA_WIDTH), .ROWS(ROWS), .COLS(COLS)
    ) u_dut (
        .clk(clk), .rst_n(rst_n), .en(en),
        .data_flow(data_flow), .load(load), .acc_en(acc_en),
        .A(A_flat_in), .B(B_flat_in), .C_acc(C_acc_in),
        .valid(valid), .C_out(C_out), .A_pass_out(A_pass_out)
    );

    // ==========================================
    // 4. 初始化与主流程
    // ==========================================
    always #5 clk = ~clk; 
    integer r, c, k;

    initial begin
        clk = 0; rst_n = 0; en = 0;
        A_flat_in = 0; B_flat_in = 0; C_acc_in = 0;
        data_flow = 0; load = 0; acc_en = 0;

        // 初始化数据: A=1, B=2 => Expected=16
        for (r=0; r<ROWS; r=r+1) for (k=0; k<K_TOTAL; k=k+1) mat_A[r][k] = r+k;
        for (k=0; k<K_TOTAL; k=k+1) for (c=0; c<COLS; c=c+1) mat_B[k][c] = K_TOTAL*2-r-k;
        
        calculate_expected(); // 计算 K=8 的完整预期结果

        #20 rst_n = 1; #20;

        // ------------------------------------------------------------
        // Test 1: OS Mode (Output Stationary) - Continuous Stream
        // ------------------------------------------------------------
        $display("\n===========================================");
        $display("TEST 1: OS MODE (Continuous Stream K=8)");
        $display("===========================================");
        
        // 直接运行一次完整的 K=8 计算
        run_os_test(); 
        
        // 验证结果
        check_results("OS Mode (K=8)");

        // ------------------------------------------------------------
        // Test 2: WS Mode (Weight Stationary) - Loopback
        // ------------------------------------------------------------
        #50; rst_n = 0; #20 rst_n = 1; // 重置
        clear_actual_result();
        
        $display("\n===========================================");
        $display("TEST 2: WS MODE (Loopback K=4+4)");
        $display("===========================================");
        
        run_ws_pass(1, 0, 0); // Pass 1
        #50;
        run_ws_pass(2, 4, 1); // Pass 2 (Loopback)
        
        check_results("WS Mode (K=8)");

        $display("\nALL TESTS FINISHED.");
        $stop;
    end

    // ==========================================
    // 任务：计算 Golden Model
    // ==========================================
    task calculate_expected;
        integer i, j, m;
        reg signed [31:0] sum;
        begin
            for (i=0; i<ROWS; i=i+1) begin
                for (j=0; j<COLS; j=j+1) begin
                    sum = 0;
                    for (m=0; m<K_TOTAL; m=m+1) sum = sum + mat_A[i][m] * mat_B[m][j];
                    mat_C_expected[i][j] = sum;
                end
            end
        end
    endtask

    task clear_actual_result;
        integer i, j;
        begin
            for (i=0; i<ROWS; i=i+1) for (j=0; j<COLS; j=j+1) mat_C_actual[i][j] = 0;
        end
    endtask

    // ==========================================
    // [核心修改] 任务：运行 OS 测试 (连续流)
    // ==========================================
    task run_os_test;
        integer t, row_idx, col_idx;
        begin
            data_flow = 0; // OS Mode
            load = 0; 
            acc_en = 0;    // OS 不需要累加使能
            en = 0;
            os_cap_cnt = 0;

            $display("-> Streaming Full Inputs (K=%0d)...", K_TOTAL);
            
            // 循环长度: 
            // K_TOTAL (数据长度) + Skew (输入偏移) + Latency (传输延迟)
            // OS 模式下，主要是为了保证输入能够完整进入。
            // K_TOTAL = 8, Skew = ROWS + COLS approx 8. Total ~20+ is safe.
            // 只要 en 拉低后，Controller 会负责剩下的 Drain 时间。
            
            for (t = 0; t < K_TOTAL + ROWS + COLS + 20; t = t + 1) begin
                
                // 1. 控制 en 信号
                // 在有效数据范围内拉高 en。注意 Skew 的影响。
                // 最晚的数据 B[Last_Col] 需要 delayed by COLS-1。
                // 我们简化处理：只要 t 在 0 到 (K_TOTAL + Skew_Max) 范围内有数据，en 就为高？
                // 实际上 PE_Status_Controller 逻辑是：en 为高期间认为是有效输入。
                // 我们需要覆盖最长的那一条数据链。
                // Row 0 的输入 A: t=0..7
                // Row 3 的输入 A: t=3..10
                // Col 3 的输入 B: t=3..10
                // 所以 en 应该在 t=0 到 t=10 (approx) 期间保持为高。
                // 更精确：en 需要覆盖直到最后一个有效数据进入阵列。
                if (t < K_TOTAL + ROWS + COLS) en = 1;
                else en = 0;

                // 2. 驱动 A (Row Skewed)
                for (r = 0; r < ROWS; r = r + 1) begin
                    col_idx = t - r; // A 的列索引 (K)
                    if (col_idx >= 0 && col_idx < K_TOTAL) 
                        A_flat_in[((r+1)*DATA_WIDTH)-1 -: DATA_WIDTH] = mat_A[r][col_idx];
                    else 
                        A_flat_in[((r+1)*DATA_WIDTH)-1 -: DATA_WIDTH] = 0;
                end

                // 3. 驱动 B (Col Skewed)
                for (c = 0; c < COLS; c = c + 1) begin
                    row_idx = t - c; // B 的行索引 (K)
                    if (row_idx >= 0 && row_idx < K_TOTAL) 
                        B_flat_in[((c+1)*DATA_WIDTH)-1 -: DATA_WIDTH] = mat_B[row_idx][c];
                    else 
                        B_flat_in[((c+1)*DATA_WIDTH)-1 -: DATA_WIDTH] = 0;
                end
                
                @(posedge clk); 
                #1; 

                // 4. 捕获输出 (Auto Drain)
                // 当 en 拉低后，PE_Status_Controller 会自动等待并拉高 valid
                if (valid) begin
                    capture_os_row(); 
                end
            end
            
            // 确保所有状态复位
            en = 0;
            @(posedge clk);
        end
    endtask

    // OS 结果捕获辅助函数
    integer os_cap_cnt = 0;
    task capture_os_row;
        integer c;
        begin
            // OS Drain 顺序：从下往上 (Row 3, Row 2, Row 1, Row 0)
            if (os_cap_cnt < ROWS) begin
                //$display("   Time %0t: Captured OS Output Row", $time);
                for (c = 0; c < COLS; c = c + 1) begin
                    mat_C_actual[ROWS - 1 - os_cap_cnt][c] = C_out[((c+1)*2*DATA_WIDTH)-1 -: 2*DATA_WIDTH];
                end
                os_cap_cnt = os_cap_cnt + 1;
            end
        end
    endtask

    // ==========================================
    // 任务：运行 WS Pass (保持之前的逻辑)
    // ==========================================
    task run_ws_pass;
        input integer pass_id;
        input integer k_start;
        input do_acc;
        
        integer t, r, c_skew;
        begin
            data_flow = 1; acc_en = do_acc; load = 0; en = 0;
            if (do_acc) fifo_rd_ptr = 0; else fifo_wr_ptr = 0;

            // Load Weights
            $display("-> [Pass %0d] Loading Weights...", pass_id);
            @(posedge clk); 
            #1; 
            load = 1; en = 0;
            for (t = 0; t < ROWS; t = t + 1) begin
                for (c = 0; c < COLS; c = c + 1) B_flat_in[((c+1)*DATA_WIDTH)-1 -: DATA_WIDTH] = mat_B[k_start + ROWS - 1 - t][c];
                @(posedge clk);
            end
            load = 0; en = 0; B_flat_in = 0;

            // Compute
            $display("-> [Pass %0d] Computing...", pass_id);
            // 这里只需运行 K_PASS (4) 的长度
            for (t = 0; t < K_PASS + ROWS + ROWS + 5; t = t + 1) begin
                for (r = 0; r < ROWS; r = r + 1) begin
                    c_skew = t - r;
                    if (c_skew >= 0 && c_skew < K_PASS) begin
                        A_flat_in[((r+1)*DATA_WIDTH)-1 -: DATA_WIDTH] = mat_A[r][k_start + c_skew];
                        en = 1;
                    end else A_flat_in[((r+1)*DATA_WIDTH)-1 -: DATA_WIDTH] = 0;
                end
                if (t >= K_PASS + ROWS) en = 0;

                // Loopback Input logic
                if (do_acc) begin
                    if (t < K_PASS + ROWS + ROWS && fifo_rd_ptr < 64) begin
                         C_acc_in = loopback_fifo[fifo_rd_ptr];
                         fifo_rd_ptr = fifo_rd_ptr + 1;
                    end else C_acc_in = 0;
                end

                @(posedge clk); #1;

                if (valid) begin
                    if (!do_acc) begin
                        loopback_fifo[fifo_wr_ptr] = C_out;
                        fifo_wr_ptr = fifo_wr_ptr + 1;
                    end else begin
                        reconstruct_ws_output();
                    end
                end
            end
        end
    endtask

    // WS 结果重构
    integer ws_val_cnt = 0;
    reg prev_valid = 0;
    always @(posedge clk) begin
        if (valid && !prev_valid) ws_val_cnt <= 0;
        else if (valid) ws_val_cnt <= ws_val_cnt + 1;
        prev_valid <= valid;
    end

    task reconstruct_ws_output;
        integer c, mapped_row;
        begin
            for (c = 0; c < COLS; c = c + 1) begin
                mapped_row = ws_val_cnt - c;
                if (mapped_row >= 0 && mapped_row < ROWS) begin
                    mat_C_actual[mapped_row][c] = C_out[((c+1)*2*DATA_WIDTH)-1 -: 2*DATA_WIDTH];
                end
            end
        end
    endtask

    // ==========================================
    // 结果检查
    // ==========================================
    task check_results;
        input [127:0] name;
        integer i, j, err;
        begin
            err = 0;
            for (i=0; i<ROWS; i=i+1) begin
                for (j=0; j<COLS; j=j+1) begin
                    if (mat_C_actual[i][j] !== mat_C_expected[i][j]) begin
                        $display("[ERROR] %s [%0d][%0d]: Act=%0d Exp=%0d", 
                                 name, i, j, mat_C_actual[i][j], mat_C_expected[i][j]);
                        err = err + 1;
                    end
                end
            end
            if (err == 0) $display("[PASS] %s: All Results Match!", name);
            else $display("[FAIL] %s: Found %0d Errors", name, err);
        end
    endtask

endmodule