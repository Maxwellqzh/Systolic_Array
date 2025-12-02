`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: hzn
// 
// Create Date: 2025/12/01 18:33:25
// Design Name: 
// Module Name: AXIS_SA_OS_tb
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


module AXIS_SA_OS_tb;
    localparam DW = 8;
    localparam OW = 16;
    localparam P  = 8;
    localparam Q  = 8;
    localparam M  = 25;
    localparam N  = 19;
    localparam L  = 17;
    localparam MAX_TILE  = 16;

    reg clk;
    reg rst_n;

    reg [7:0] row_len;
    reg [7:0] col_len;
    reg [7:0] k_len;
    reg finish;
    wire compute_done;

    reg  [DW-1:0] s_axis_i_tdata;
    reg           s_axis_i_tvalid;
    wire          s_axis_i_tready;
    reg           s_axis_i_tlast;

    wire [OW-1:0] m_axis_o_tdata;
    wire          m_axis_o_tvalid;
    reg           m_axis_o_tready;
    wire          m_axis_o_tlast;

    // =====================================================
    // DUT
    // =====================================================
    AXIS_SA_OS #(
        .DW(DW),
        .OW(OW),
        .P(P),
        .Q(Q)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .row_len(row_len),
        .col_len(col_len),
        .k_len(k_len),
        .finish(finish),
        .compute_done(compute_done),

        .s_axis_i_tdata(s_axis_i_tdata),
        .s_axis_i_tvalid(s_axis_i_tvalid),
        .s_axis_i_tready(s_axis_i_tready),
        .s_axis_i_tlast(s_axis_i_tlast),

        .m_axis_o_tdata(m_axis_o_tdata),
        .m_axis_o_tvalid(m_axis_o_tvalid),
        .m_axis_o_tready(m_axis_o_tready),
        .m_axis_o_tlast(m_axis_o_tlast)
    );

    // ==========================================================
    // M / N / L 三方向 tiles 划分
    // ==========================================================

    integer qM, rM;
    reg[7:0] baseM, remM;
    reg [7:0] tile_cnt_M;
    reg [7:0] tile_size_M [0:MAX_TILE-1];
    reg [7:0] tile_start_M[0:MAX_TILE-1];

    integer qN, rN;
    reg[7:0] baseN, remN;
    reg [7:0] tile_cnt_N;
    reg [7:0] tile_size_N [0:MAX_TILE-1];
    reg [7:0] tile_start_N[0:MAX_TILE-1];

    integer qL, rL;
    reg[7:0] baseL, remL;
    reg [7:0] tile_cnt_L;
    reg [7:0] tile_size_L [0:MAX_TILE-1];
    reg [7:0] tile_start_L[0:MAX_TILE-1];

    integer i,j;

    initial begin
        // ---------------- M 方向分块（按 P 均匀划分） ---------------
        qM = M / P;
        rM = M % P;
        tile_cnt_M = (rM == 0) ? qM : qM + 1;

        baseM = M / tile_cnt_M;
        remM  = M % tile_cnt_M;

        for(i = 0; i < tile_cnt_M; i = i + 1)
            tile_size_M[i] = (i < remM) ? (baseM + 1) : baseM;

        tile_start_M[0] = 0;
        for(i = 1; i < tile_cnt_M; i = i + 1)
            tile_start_M[i] = tile_start_M[i-1] + tile_size_M[i-1];

        // ---------------- N 方向分块（按 P 均匀划分） ---------------
        qN = N / P;
        rN = N % P;
        tile_cnt_N = (rN == 0) ? qN : qN + 1;

        baseN = N / tile_cnt_N;
        remN  = N % tile_cnt_N;

        for(i = 0; i < tile_cnt_N; i = i + 1)
            tile_size_N[i] = (i < remN) ? (baseN + 1) : baseN;

        tile_start_N[0] = 0;
        for(i = 1; i < tile_cnt_N; i = i + 1)
            tile_start_N[i] = tile_start_N[i-1] + tile_size_N[i-1];

        // ---------------- L 方向分块（按 Q 均匀划分） ---------------
        qL = L / Q;
        rL = L % Q;
        tile_cnt_L = (rL == 0) ? qL : qL + 1;

        baseL = L / tile_cnt_L;
        remL  = L % tile_cnt_L;

        for(i = 0; i < tile_cnt_L; i = i + 1)
            tile_size_L[i] = (i < remL) ? (baseL + 1) : baseL;

        tile_start_L[0] = 0;
        for(i = 1; i < tile_cnt_L; i = i + 1)
            tile_start_L[i] = tile_start_L[i-1] + tile_size_L[i-1];
    end

    // =====================================================
    // clock
    // =====================================================
    always #5 clk = ~clk;

    // =====================================================
    // 发送输入矩阵
    // =====================================================
    task send_matrix_big;
        input [7:0] rows;
        input [7:0] cols;
        input [7:0] tile_row_start;
        input [7:0] tile_col_start;
        input       is_B;   // 0=A，1=B
    begin
        wait(s_axis_i_tready == 1);
        @(posedge clk);
        for (i = 0; i < rows; i = i + 1) begin
            for (j = 0; j < cols; j = j + 1) begin
                
                @(posedge clk);
    
                if(!is_B)
                    s_axis_i_tdata <= (tile_row_start + i)*1 + (tile_col_start + j);
                else
                    s_axis_i_tdata <= (tile_row_start + i)*2 + (tile_col_start + j) + 1;
    
                s_axis_i_tvalid <= 1;
                s_axis_i_tlast  <= ((i==rows-1)&&(j==cols-1));
    
                while(!s_axis_i_tready) @(posedge clk);
            end
        end
    
        @(posedge clk);
        s_axis_i_tvalid <= 0;
        s_axis_i_tlast  <= 0;
    end
    endtask

    // =====================================================
    // 读取输出矩阵
    // =====================================================
    task read_output;
        integer cnt;
        begin
            cnt = 0;
            m_axis_o_tready = 1;
    
            @(posedge clk);
            while(1) begin
                @(posedge clk);
                if(m_axis_o_tvalid) begin
                    $display("OUT[%0d] = %0d", cnt, m_axis_o_tdata);
                    cnt = cnt + 1;
                end
                if(m_axis_o_tvalid && m_axis_o_tlast)
                    disable read_output;
            end
        end
    endtask


    // =====================================================
    // TB 主流程
    // =====================================================
    integer iM, iN, iL;
    initial begin
        clk = 0;
        rst_n = 1;

        s_axis_i_tvalid = 0;
        s_axis_i_tlast  = 0;
        finish          = 0;
        m_axis_o_tready = 1;
        
        #20;
        rst_n = 0;
        #20;
        rst_n = 1;

        #20;
        rst_n = 0;
        #20;
        rst_n = 1;
        #30;

        // --------------------------------------------
        // 三层 tile 循环
        // --------------------------------------------
        for(iM = 0; iM < tile_cnt_M; iM = iM + 1) begin          // 最外层：M 行块
            row_len = tile_size_M[iM];
            for(iL = 0; iL < tile_cnt_L; iL = iL + 1) begin      // 中间层：L 列块
                col_len = tile_size_L[iL];
        
                // =========================================================================
                // 初始化：一个 C_tile = 4×4 块将被计算，先把 finish 拉低
                // =========================================================================
                finish = 0;
        
                for(iN = 0; iN < tile_cnt_N; iN = iN + 1) begin  // 最内层：N 累加块
                     k_len = tile_size_N[iN];
                    // ==========================
                    // 最后一个 N-tile，拉高 finish
                    // ==========================
                    if(iN == tile_cnt_N-1)
                        finish = 1;
                    else
                        finish = 0;
                    // A_tile (iM,iN)
                    send_matrix_big(
                        row_len, k_len,
                        tile_start_M[iM], tile_start_N[iN],
                        0
                    );

                    // B_tile (iN,iL)
                    send_matrix_big(
                        k_len, col_len,
                        tile_start_N[iN], tile_start_L[iL],
                        1
                    );
                    wait(compute_done == 1);
                end // end for iN
        
                // =========================================================================
                // 在 N 累加全部完成 (finish=1) 后，输出最终的 C_tile
                // =========================================================================
                read_output();
        
            end // end for iL
        end // end for iM

        #20;
        $finish;
    end

endmodule
