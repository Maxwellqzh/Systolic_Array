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
    parameter DW = 8,       // 输入位宽
    parameter OW = 16,      // 输出位宽
    parameter P  = 8,       // tile M,N 方向阵列大小
    parameter Q  = 8       // tile L 方向阵列大小
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [7:0] row_len,
    input  wire [7:0] col_len,
    input  wire [7:0] k_len,
    input  wire finish,
    output reg compute_done,

    // AXIS 输入 
    input  wire [DW-1:0] s_axis_i_tdata,
    input  wire          s_axis_i_tvalid,
    output reg           s_axis_i_tready,
    input  wire          s_axis_i_tlast,

    // AXIS 输出 
    output reg  [OW-1:0] m_axis_o_tdata,
    output reg           m_axis_o_tvalid,
    input  wire          m_axis_o_tready,
    output reg           m_axis_o_tlast
);  
    localparam  S_IDLE = 0,
                S_LOAD_A = 1,
                S_LOAD_B = 2,
                S_COMPUTE = 3,
                S_READ = 4,
                S_WRITE  = 5;

    reg [2:0] state, next_state;

    reg signed [DW-1:0] a_matrix [0:P-1][0:Q-1];
    reg signed [DW-1:0] b_matrix [0:P-1][0:Q-1];
    reg signed [OW-1:0] c_matrix [0:P-1][0:Q-1];

    reg[7:0] mi_a,lj_a;
    reg[7:0] ai, aj;
    reg[7:0] mi_b,lj_b;
    reg[7:0] bi, bj;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ai <= 0;
            aj <= 0;
            bi <= 0;    
            bj <= 0;
            s_axis_i_tready <= 0;
            for (mi_a = 0; mi_a < P; mi_a = mi_a + 1)
                for (lj_a = 0; lj_a < Q; lj_a = lj_a + 1)
                    a_matrix[mi_a][lj_a] <= 0;
            for (mi_b = 0; mi_b < P; mi_b = mi_b + 1)
                for (lj_b = 0; lj_b < Q; lj_b = lj_b + 1)
                    b_matrix[mi_b][lj_b] <= 0;
        end
        else begin        
            if((state == S_LOAD_A && !s_axis_i_tlast) || (state == S_LOAD_B && !s_axis_i_tlast))
                s_axis_i_tready <= 1;
            else s_axis_i_tready <= 0;
            
            if(state == S_LOAD_A && s_axis_i_tvalid) begin
                a_matrix[ai][aj] <= s_axis_i_tdata;
                if(aj == k_len-1) begin
                    aj <= 0;
                    ai <= ai + 1;
                end
                else begin
                    aj <= aj + 1;
                end
            end
    
            else if(state == S_LOAD_B && s_axis_i_tvalid) begin
                b_matrix[bi][bj] <= s_axis_i_tdata;
    
                if(bj == col_len-1) begin
                    bj <= 0;
                    bi <= bi + 1;
                end
                else begin
                    bj <= bj + 1;
                end
            end
            
            if(s_axis_i_tlast) begin
                ai <= 0;
                aj <= 0;
                bi <= 0;
                bj <= 0;
            end
        end
    end

    // systolic array 端口
    reg compute_en;
    wire read_valid;
    wire data_flow = 0;
    wire load = 0;
    wire acc_en = 0;
    wire [Q*OW-1:0]C_acc = 0;
    wire signed [P*DW-1:0] A_bus;
    wire signed [Q*DW-1:0] B_bus;
    wire signed [Q*OW-1:0] C_bus;

    reg  signed [DW-1:0] A_row [0:P-1];
    reg  signed [DW-1:0] B_col [0:Q-1];
    wire signed [OW-1:0] C_col [0:Q-1];
    
    genvar gi;
    generate
        for (gi = 0; gi < P; gi = gi + 1) begin: GEN_I_BUS
            assign A_bus[(gi+1)*DW-1 -: DW] = A_row[gi];
        end

        for (gi = 0; gi < Q; gi = gi + 1) begin: GEN_W_BUS
            assign B_bus[(gi+1)*DW-1 -: DW] = B_col[gi];
        end

        for (gi = 0; gi < Q; gi = gi + 1) begin: GEN_R_BUS
            assign C_col[gi] = C_bus[(gi+1)*OW-1 -: OW];
        end
    endgenerate

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
    

    reg [7:0] tile_cnt;
    wire [7:0] latency;

    assign latency = row_len + k_len + col_len - 1;
    reg [7:0] mi,lj;
    // 输入阵列
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tile_cnt <= 0;
            compute_en <= 0;
            compute_done <= 0;
            for (mi = 0; mi < P; mi = mi + 1) A_row[mi] <= 0;
            for (lj = 0; lj < Q; lj = lj + 1) B_col[lj] <= 0;
        end
        else begin
            if(state == S_COMPUTE) begin
                if(tile_cnt == 0) compute_en <= 1;
                else if (tile_cnt == latency && finish) compute_en <= 0;

                if(tile_cnt < latency) tile_cnt <= tile_cnt + 1;
                else tile_cnt <= tile_cnt;
                
                if(tile_cnt == latency) compute_done <= 1;
                else compute_done <= 0;

                if(tile_cnt < latency) begin
                    for (mi = 0; mi < P; mi = mi + 1) begin
                        if (mi <= row_len && mi <= tile_cnt && tile_cnt - mi < k_len) A_row[mi] <= a_matrix[mi][tile_cnt - mi];
                        else A_row[mi] <= 0;
                    end
                    for (lj = 0; lj < Q; lj = lj + 1) begin
                        if (lj <= col_len && lj <= tile_cnt && tile_cnt - lj < k_len) B_col[lj] <= b_matrix[tile_cnt - lj][lj];
                        else B_col[lj] <= 0;
                    end
                end
                else begin
                    for (mi = 0; mi < P; mi = mi + 1) A_row[mi] <= 0;
                    for (lj = 0; lj < Q; lj = lj + 1) B_col[lj] <= 0;
                end
            end

            else begin
                compute_done <= 0;
                tile_cnt <= 0;
                for (mi = 0; mi < P; mi = mi + 1) A_row[mi] <= 0;
                for (lj = 0; lj < Q; lj = lj + 1) B_col[lj] <= 0;
            end
        end
    end   
    
    // 读取阵列结果
    reg[7:0] mi_r,lj_r;
    reg[7:0] read_cnt;
    wire [7:0] read_latency = P - 1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (mi_r = 0; mi_r < P; mi_r = mi_r + 1)
                for (lj_r = 0; lj_r < Q; lj_r = lj_r + 1)
                    c_matrix[mi_r][lj_r] <= 0;
            read_cnt <= 0;
        end
        else begin
            if(state == S_READ && read_valid) begin
                if(read_cnt < read_latency) read_cnt <= read_cnt + 1;
                else read_cnt <= 0;
                if(read_cnt <= read_latency)begin
                    for (lj_r = 0; lj_r < Q; lj_r = lj_r + 1) begin
                        if (read_latency - read_cnt < row_len && lj_r < col_len) c_matrix[read_latency - read_cnt][lj_r] <= C_col[lj_r];
                        else c_matrix[read_latency - read_cnt][lj_r] <= 0;
                    end
                end
            end
            else read_cnt <= 0;
        end
    end
    
    // ==========================================================
    // AXIS 输出
    // ==========================================================
    reg[7:0] crow, ccol;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axis_o_tvalid <= 0;
            m_axis_o_tlast  <= 0;
            m_axis_o_tdata  <= {OW{1'b0}};
            crow <= 0;
            ccol <= 0;
        end
        else begin
            if (state == S_WRITE) begin
                m_axis_o_tvalid <= 1;
                m_axis_o_tdata  <= c_matrix[crow][ccol];

                if (m_axis_o_tready) begin
                    // 是否是最后一个元素
                    if (crow == row_len-1 && ccol == col_len-1) begin
                        m_axis_o_tlast <= 1;
                        crow <= 0;
                        ccol <= 0;
                    end
                    else begin
                        m_axis_o_tlast <= 0;
                        if (ccol == col_len-1) begin
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
                m_axis_o_tvalid <= 0;
                m_axis_o_tlast  <= 0;
                crow <= 0;
                ccol <= 0;
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
                if(s_axis_i_tlast) begin
                    next_state = S_LOAD_B;
                end
            end
            
            S_LOAD_B: begin
                if(s_axis_i_tlast) begin
                    next_state = S_COMPUTE;
                end
            end
            
            S_COMPUTE: begin
                if(tile_cnt == latency)begin
                     if(finish) next_state = S_READ;
                     else next_state = S_LOAD_A;
                end
            end
        
            S_READ: begin
                if(read_cnt == read_latency) next_state = S_WRITE;
            end

            S_WRITE: begin
               if(m_axis_o_tlast) next_state = S_IDLE;
            end
        
            default: next_state = S_IDLE;
        endcase
    end  
    

endmodule

