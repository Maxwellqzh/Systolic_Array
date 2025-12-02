`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/12/01 21:01:53
// Design Name: 
// Module Name: AXIS_SA_WS
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


module AXIS_SA_WS #(
    parameter DW = 8,       // 输入位宽
    parameter OW = 16,      // 输出位宽
    parameter P  = 8,       // tile M,N 方向阵列大小
    parameter Q  = 8       // tile L 方向阵列大小
)(
    input  wire clk,
    input  wire rst_n,
    input  wire load_control,

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
                S_LOAD_input = 1,
                S_LOAD_weight = 2,
                S_SET_weight = 3,
                S_COMPUTE = 4,
                S_WRITE  = 5;

    reg [2:0] state, next_state;

    reg signed [DW-1:0] input_matrix [0:P-1][0:Q-1];
    reg signed [DW-1:0] weight_matrix [0:P-1][0:Q-1];
    reg signed [OW-1:0] result_matrix [0:P-1][0:Q-1];

    reg[7:0] mi_i,lj_i;
    reg[7:0] ii, ij;
    reg[7:0] mi_w,lj_w;
    reg[7:0] wi, wj;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ii <= 0;
            ij <= 0;
            wi <= 0;    
            wj <= 0;
            s_axis_i_tready <= 0;
            for (mi_i = 0; mi_i < P; mi_i = mi_i + 1)
                for (lj_i = 0; lj_i < Q; lj_i = lj_i + 1)
                    input_matrix[mi_i][lj_i] <= 0;
            for (mi_w = 0; mi_w < P; mi_w = mi_w + 1)
                for (lj_w = 0; lj_w < Q; lj_w = lj_w + 1)
                    weight_matrix[mi_w][lj_w] <= 0;
        end
        else begin        
            if((state == S_LOAD_input && !s_axis_i_tlast) || (state == S_LOAD_weight && !s_axis_i_tlast))
                s_axis_i_tready <= 1;
            else s_axis_i_tready <= 0;
            
            if(state == S_LOAD_input && s_axis_i_tvalid) begin
                input_matrix[ii][ij] <= s_axis_i_tdata;
                if(ij == Q-1) begin
                    ij <= 0;
                    ii <= ii + 1;
                end
                else begin
                    ij <= ij + 1;
                end
            end
    
            else if(state == S_LOAD_weight && s_axis_i_tvalid) begin
                weight_matrix[wi][wj] <= s_axis_i_tdata;
    
                if(wj == Q-1) begin
                    wj <= 0;
                    wi <= wi + 1;
                end
                else begin
                    wj <= wj + 1;
                end
            end
            
            if(s_axis_i_tlast) begin
                ii <= 0;
                ij <= 0;
                wi <= 0;
                wj <= 0;
            end
        end
    end

    // systolic array 端口
    reg compute_en;
    wire read_valid;
    wire data_flow = 1;
    reg load;
    wire acc_en = 0;
    wire [Q*OW-1:0]C_acc = 0;
    wire signed [P*DW-1:0] I_bus;
    wire signed [Q*DW-1:0] W_bus;
    wire signed [Q*OW-1:0] R_bus;

    reg  signed [DW-1:0] I_row [0:P-1];
    reg  signed [DW-1:0] W_col [0:Q-1];
    wire signed [OW-1:0] R_col [0:Q-1];
    
    genvar gi;
    generate
        for (gi = 0; gi < P; gi = gi + 1) begin: GEN_I_BUS
            assign I_bus[(gi+1)*DW-1 -: DW] = I_row[gi];
        end

        for (gi = 0; gi < Q; gi = gi + 1) begin: GEN_W_BUS
            assign W_bus[(gi+1)*DW-1 -: DW] = W_col[gi];
        end

        for (gi = 0; gi < Q; gi = gi + 1) begin: GEN_R_BUS
            assign R_col[gi] = R_bus[(gi+1)*OW-1 -: OW];
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
        .A(I_bus),
        .B(W_bus),
        .C_out(R_bus),
        .C_acc(C_acc)
    );
    

    reg [7:0] load_cnt;
    reg [7:0] tile_cnt;
    wire [7:0] latency = P + Q - 1;
    reg [7:0] mi,lj;
    // 输入阵列
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tile_cnt <= 0;
            load_cnt <= 0;
            compute_en <= 0;
            load <= 0;
            for (mi = 0; mi < P; mi = mi + 1) I_row[mi] <= 0;
            for (lj = 0; lj < Q; lj = lj + 1) W_col[lj] <= 0;
        end
        else begin
            if(state == S_SET_weight) begin
                if(load_cnt == 0) load <= 1;
                else if(load_cnt == P) load <= 0;

                if(load_cnt < P) load_cnt <= load_cnt + 1;
                else load_cnt <= 0;

                if(load_cnt < P) begin
                    for (lj = 0; lj < Q; lj = lj + 1) W_col[lj] <= weight_matrix[P - 1 - load_cnt][lj]; 
                end
                else begin
                    for (lj = 0; lj < Q; lj = lj + 1) W_col[lj] <= 0;
                end
            end

            else if(state == S_COMPUTE) begin
                if(tile_cnt == 0) compute_en <= 1;
                else if (tile_cnt == latency) compute_en <= 0;

                if(tile_cnt < latency) tile_cnt <= tile_cnt + 1;
                else tile_cnt <= tile_cnt;

                if(tile_cnt < latency) begin
                    for (mi = 0; mi < P; mi = mi + 1) begin
                        if (mi <= tile_cnt && tile_cnt - mi < P) I_row[mi] <= input_matrix[tile_cnt - mi][mi];
                        else I_row[mi] <= 0;
                    end
                end
                else begin
                    for (mi = 0; mi < P; mi = mi + 1) I_row[mi] <= 0;
                end
            end

            else begin
                tile_cnt <= 0;
                load_cnt <= 0;
                compute_en <= 0;
                load <= 0;
                for (mi = 0; mi < P; mi = mi + 1) I_row[mi] <= 0;
                for (lj = 0; lj < Q; lj = lj + 1) W_col[lj] <= 0;
            end
        end
    end   
    
    // 读取阵列结果
    reg[7:0] mi_r,lj_r;
    reg[7:0] read_cnt;
    wire [7:0] read_latency = P + Q - 1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (mi_r = 0; mi_r < P; mi_r = mi_r + 1)
                for (lj_r = 0; lj_r < Q; lj_r = lj_r + 1)
                    result_matrix[mi_r][lj_r] <= 0;
            read_cnt <= 0;
        end
        else begin
            if(read_valid) begin
                if(read_cnt < read_latency) read_cnt <= read_cnt + 1;
                else read_cnt <= 0;

                if(read_cnt < read_latency)begin
                    for (lj_r = 0; lj_r < Q; lj_r = lj_r + 1) begin
                        if (lj_r <= read_cnt && read_cnt - lj_r < P) result_matrix[read_cnt - lj_r][lj_r] <= R_col[lj_r];
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
                m_axis_o_tdata  <= result_matrix[crow][ccol];

                if (m_axis_o_tready) begin
                    // 是否是最后一个元素
                    if (crow == P-1 && ccol == Q-1) begin
                        m_axis_o_tlast <= 1;
                        crow <= 0;
                        ccol <= 0;
                    end
                    else begin
                        m_axis_o_tlast <= 0;
                        if (ccol == Q-1) begin
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
            S_IDLE: next_state = S_LOAD_input;
        
            S_LOAD_input: begin
                if(s_axis_i_tlast) begin
                    if(load_control) next_state = S_LOAD_weight;
                    else next_state = S_COMPUTE;
                end
            end
        
            S_LOAD_weight: begin
                if(s_axis_i_tlast) begin
                    next_state = S_SET_weight;
                end
            end
        
            S_SET_weight: begin
                if (load_cnt == P) next_state = S_COMPUTE;
            end
            
            S_COMPUTE: begin
                if(read_cnt == read_latency) next_state = S_WRITE;
            end
        
            S_WRITE: begin
               if(m_axis_o_tlast) next_state = S_IDLE;
            end
        
            default: next_state = S_IDLE;
        endcase
    end  
    

endmodule
