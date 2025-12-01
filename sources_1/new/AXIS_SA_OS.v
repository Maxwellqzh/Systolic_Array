`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: hzn
// 
// Create Date: 2025/12/01 18:32:23
// Design Name: 
// Module Name: AXIS_SA_OS
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


module AXIS_SA_OS #(
    parameter M  = 25,      // A = M×N
    parameter N  = 19,      // B = N×L
    parameter L  = 17,      // C = M×L
    parameter DW = 8,       // 输入位宽
    parameter OW = 16,      // 输出位宽
    parameter P  = 8,       // tile M,N 方向阵列大小
    parameter Q  = 8,       // tile L 方向阵列大小
    parameter MAX_TILE = 16
)(
    input  wire clk,
    input  wire rst_n,

    // AXIS 输入 A
    input  wire [DW-1:0] s_axis_a_tdata,
    input  wire          s_axis_a_tvalid,
    output reg           s_axis_a_tready,
    input  wire          s_axis_a_tlast,

    // AXIS 输入 B
    input  wire [DW-1:0] s_axis_b_tdata,
    input  wire          s_axis_b_tvalid,
    output reg           s_axis_b_tready,
    input  wire          s_axis_b_tlast,

    // AXIS 输出 C
    output reg  [OW-1:0] m_axis_c_tdata,
    output reg           m_axis_c_tvalid,
    input  wire          m_axis_c_tready,
    output reg           m_axis_c_tlast
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

    integer i;

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
    
    reg [7:0] m_off, n_off, l_off;
    reg [7:0] m_size, n_size, l_size;
    reg [7:0] m_off_last, n_off_last, l_off_last;
    reg [7:0] m_size_last, n_size_last, l_size_last;
    
    reg [3:0] tile_m, tile_n, tile_l;
    
    reg tile_total_finish;
    reg tile_row_finish;
    reg tile_col_finish;
    
    reg [7:0]tile_cnt;
    wire [7:0] tile_cnt_rw = (tile_cnt - 8'd2) & 8'hFF;
    wire [9:0] latency = m_size + n_size + l_size;
    wire tile_finish;
    assign tile_finish = (tile_cnt == latency);
    
    localparam S_IDLE   = 0,
                S_LOAD_A = 1,
                S_LOAD_B = 2,
                S_TILE   = 3,
                S_WAIT_TILE= 4,
                S_WAIT_COL= 5,
                S_WAIT_ROW= 6,
                S_WRITE  = 7;

    reg [2:0] state, next_state;
    
    // ==========================================================
    // 矩阵 A / B 加载（按行 / 按列）
    // ==========================================================
    reg signed [DW-1:0] A [0:M-1][0:N-1];
    reg signed [DW-1:0] B [0:N-1][0:L-1];
    reg signed [OW-1:0] C [0:M-1][0:L-1];

    integer ai, aj;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ai <= 0;
            aj <= 0;
            s_axis_a_tready <= 1;
        end
        else if(state == S_LOAD_A && s_axis_a_tvalid) begin

            A[ai][aj] <= s_axis_a_tdata;

            if(aj == N-1) begin
                aj <= 0;
                ai <= ai + 1;
            end
            else begin
                aj <= aj + 1;
            end
        end

        // 完成 M×N 加载后自动清零计数器
        else if(state == S_LOAD_A && s_axis_a_tlast) begin
            ai <= 0;
            aj <= 0;
        end
    end

    integer bi, bj;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            bi <= 0;
            bj <= 0;
            s_axis_b_tready <= 1;
        end
        else if(state == S_LOAD_B && s_axis_b_tvalid) begin

            B[bi][bj] <= s_axis_b_tdata;

            if(bj == L-1) begin
                bj <= 0;
                bi <= bi + 1;
            end
            else begin
                bj <= bj + 1;
            end
        end

        // 完成 N×L 加载后自动清零计数器
        else if(state == S_LOAD_B && s_axis_b_tlast) begin
            bi <= 0;
            bj <= 0;
        end
    end

    // systolic array 端口
    reg compute_en;
    wire read_valid;
    wire data_flow = 0;
    wire load = 0;
    wire acc_en = 0;
    wire [Q*OW-1:0]C_acc = 0;

    // A 输入（P 行）
    reg  signed [DW-1:0] A_row [0:P-1];

    // B 输入（Q 列）
    reg  signed [DW-1:0] B_col [0:Q-1];

    // systolic 1D inputs
    wire signed [P*DW-1:0] A_bus;
    wire signed [Q*DW-1:0] B_bus;

    genvar gi;
    generate
        for (gi = 0; gi < P; gi = gi + 1) begin: GEN_ABUS
            assign A_bus[(gi+1)*DW-1 -: DW] = A_row[gi];
        end

        for (gi = 0; gi < Q; gi = gi + 1) begin: GEN_BBUS
            assign B_bus[(gi+1)*DW-1 -: DW] = B_col[gi];
        end
    endgenerate

    // systolic 阵列输出
    wire signed [Q*OW-1:0] C_bus;

    // ----------------------------------------------------------
    // 固定 P×Q systolic array 实例化
    // ----------------------------------------------------------
    PE_Array #(
        .ROWS(P),
        .COLS(Q),
        .DATA_WIDTH(DW)
    ) U_TILE (
        .clk(clk),
        .rst_n(rst_n),
        .en(compute_en),
        .valid(read_valid),
        .data_flow(data_flow),
        .load(load),
        .acc_en(acc_en),
        .A(A_bus),
        .B(B_bus),
        .C_out(C_bus),
        .C_acc(C_acc)
    );
    
    reg read_valid_d1;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            read_valid_d1 <= 0;
        end
        else begin
            read_valid_d1 <= read_valid;
        end
    end
    
    reg signed [Q*OW-1:0] C_bus_d1;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            C_bus_d1 <= 0;
        end
        else begin
            C_bus_d1 <= C_bus;
        end
    end
    
    // 矩阵位置切换
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            tile_m <= 0;
            tile_n <= 0;
            tile_l <= 0;
            tile_col_finish <= 0;
            tile_row_finish <= 0;
            tile_total_finish <= 0;
        end
        else if (tile_finish && state == S_TILE) begin
            if (tile_n < tile_cnt_N-1) tile_n<=tile_n+1; 
            else begin
                tile_n <= 0;
                tile_col_finish <= 1;
            end
        end
        else if (tile_col_finish && next_state == S_WAIT_COL) begin
            tile_col_finish <= 0;
            if (tile_l < tile_cnt_L-1) tile_l<=tile_l+1; 
            else begin
                tile_l <= 0;
                tile_row_finish <= 1;
            end
        end
        else if(tile_row_finish && next_state == S_WAIT_ROW) begin
            tile_row_finish <= 0;
            if (tile_m < tile_cnt_M-1) tile_m<=tile_m+1; 
            else begin
                tile_m <= 0;
                tile_total_finish <= 1;
            end
        end
        else if(tile_total_finish && next_state == S_WRITE)tile_total_finish <= 0;
    end
    

    // 组合逻辑：根据当前 tM/tN/tL 选择 offset 和 size
    always @(*) begin
        m_off  = tile_start_M[tile_m];
        m_size = tile_size_M[tile_m];

        n_off  = tile_start_N[tile_n];
        n_size = tile_size_N[tile_n];

        l_off  = tile_start_L[tile_l];
        l_size = tile_size_L[tile_l];
    end
    
    // 读取数据的矩阵位置
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_off_last <= 0;
            n_off_last <= 0;
            l_off_last <= 0;
            m_size_last <= 0; 
            n_size_last <= 0; 
            l_size_last <= 0;
        end
        else if(state == S_TILE) begin
            m_off_last <= m_off;
            n_off_last <= n_off;
            l_off_last <= l_off;
            m_size_last <= m_size; 
            n_size_last <= n_size; 
            l_size_last <= l_size;
        end
    end
    
    // 读取阵列结果
    reg[7:0] ii;
    reg [7:0] ci,cj;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (ci = 0; ci < M; ci = ci + 1)
                for (cj = 0; cj < L; cj = cj + 1)
                    C[ci][cj] <= 0;
            ii <= m_off_last + P - 1;
        end
        else if (state == S_WAIT_COL && (read_valid||read_valid_d1)) begin
            // 将 C_tile 写回对应的 C[m_off + ii][l_off + cj]
            if (ii <= m_off_last+m_size_last-1 && ii >= m_off_last)begin
                for (cj = 0; cj < l_size_last; cj = cj + 1) begin
                    if (cj < Q) C[ii][l_off_last + cj] <= C_bus_d1[((cj + 1)*OW - 1) -: OW];
                end 
            end
            ii <= ii - 1;
        end
        else ii <= m_off_last + P - 1;
    end
    
    
    
    reg[7:0] mi,lj;
    // 输入阵列
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tile_cnt <= 0;
            compute_en <= 0;
            for (mi = 0; mi < P; mi = mi + 1) A_row[mi] <= 0;
            for (lj = 0; lj < Q; lj = lj + 1) B_col[lj] <= 0;
        end
        else begin
            if(state == S_TILE) begin
                if(tile_cnt==0) begin
                    compute_en <= 1;
                end
                else begin 
                    if(tile_cnt<latency)begin
                        for (mi = 0; mi < P; mi = mi + 1) begin
                            if (mi < m_size && tile_cnt_rw >= mi && (tile_cnt_rw-mi) < n_size) A_row[mi] <= A[m_off + mi][n_off + tile_cnt_rw - mi];
                            else A_row[mi] <= 0;
                        end
                        for (lj = 0; lj < Q; lj = lj + 1) begin
                            if (lj < l_size && tile_cnt_rw >= lj && (tile_cnt_rw-lj) < n_size) B_col[lj] <= B[n_off + tile_cnt_rw - lj][l_off + lj];
                            else B_col[lj] <= 0;
                        end
                    end
                    else begin
                        for (mi = 0; mi < P; mi = mi + 1) A_row[mi] <= 0;
                        for (lj = 0; lj < Q; lj = lj + 1) B_col[lj] <= 0;
                    end
                end

                if(tile_cnt < latency) tile_cnt <= tile_cnt + 1;
                else tile_cnt <= 0;
                
            end
            else begin
                tile_cnt <= 0;
                compute_en <= 0;
            end
        end
    end   

    // ==========================================================
    // 顶层 FSM 状态
    // ==========================================================
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) state <= S_IDLE;
        else       state <= next_state;
    end
    // ==========================================================
    // next_state 逻辑
    // ==========================================================
    always @(*) begin
        next_state = state;
        case(state)
            S_IDLE: next_state = S_LOAD_A;
        
            S_LOAD_A: begin
                if(s_axis_a_tvalid && s_axis_a_tlast)
                    next_state = S_LOAD_B;
            end
        
            S_LOAD_B: begin
                if(s_axis_b_tvalid && s_axis_b_tlast) next_state = S_TILE;
            end
        
            S_TILE: begin
                if (tile_col_finish) begin
                    next_state = S_WAIT_TILE;
                end
            end
        
            S_WAIT_TILE: begin
                if (read_valid) next_state = S_WAIT_COL;
            end

            S_WAIT_COL: begin
                if (!read_valid_d1) begin
                    if(tile_row_finish) next_state = S_WAIT_ROW;
                    else next_state = S_TILE;
                end
            end
            
            S_WAIT_ROW: begin
                if(tile_total_finish) next_state = S_WRITE;
                else next_state = S_TILE;
            end
        
            S_WRITE: begin
               next_state = S_WRITE;
            end
        
            default: next_state = S_IDLE;
        endcase
    end  
    
    // ==========================================================
    // AXIS 输出阶段 (S_OUT)：按行输出全局 C(M×L)
    //   输出顺序：
    //      C[0][0], C[0][1], ..., C[0][L-1],
    //      C[1][0], ...,      C[M-1][L-1]
    //   最后一个元素时拉高 m_axis_c_tlast
    // ==========================================================
    integer crow, ccol;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axis_c_tvalid <= 0;
            m_axis_c_tlast  <= 0;
            m_axis_c_tdata  <= {OW{1'b0}};
            crow <= 0;
            ccol <= 0;
        end
        else begin
            if (state == S_WRITE) begin
                m_axis_c_tvalid <= 1;
                m_axis_c_tdata  <= C[crow][ccol];

                if (m_axis_c_tready) begin
                    // 是否是最后一个元素
                    if (crow == M-1 && ccol == L-1) begin
                        m_axis_c_tlast <= 1;
                        crow <= 0;
                        ccol <= 0;
                    end
                    else begin
                        m_axis_c_tlast <= 0;
                        if (ccol == L-1) begin
                            ccol <= 0;
                            crow <= crow + 1;
                        end
                        else begin
                            ccol <= ccol + 1;
                        end
                    end
                end
            end
            else begin
                m_axis_c_tvalid <= 0;
                m_axis_c_tlast  <= 0;
                crow <= 0;
                ccol <= 0;
            end
        end
    end
endmodule

