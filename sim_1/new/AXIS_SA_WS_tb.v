`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: hzn
// 
// Create Date: 2025/12/02 14:12:44
// Design Name: 
// Module Name: AXIS_SA_WS_tb
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


module AXIS_SA_WS_tb;
    
    localparam DW = 8;
    localparam OW = 16;
    localparam P  = 8;
    localparam Q  = 8;

    reg clk;
    reg rst_n;

    // DUT AXIS ports
    reg  [DW-1:0] s_axis_i_tdata;
    reg           s_axis_i_tvalid;
    wire          s_axis_i_tready;
    reg           s_axis_i_tlast;

    wire [OW-1:0] m_axis_o_tdata;
    wire          m_axis_o_tvalid;
    reg           m_axis_o_tready;
    wire          m_axis_o_tlast;

    reg load_control;

    // Instantiate DUT
    AXIS_SA_WS #(
        .DW(DW),
        .OW(OW),
        .P(P),
        .Q(Q)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .load_control(load_control),

        .s_axis_i_tdata(s_axis_i_tdata),
        .s_axis_i_tvalid(s_axis_i_tvalid),
        .s_axis_i_tready(s_axis_i_tready),
        .s_axis_i_tlast(s_axis_i_tlast),

        .m_axis_o_tdata(m_axis_o_tdata),
        .m_axis_o_tvalid(m_axis_o_tvalid),
        .m_axis_o_tready(m_axis_o_tready),
        .m_axis_o_tlast(m_axis_o_tlast)
    );

    // Clock
    always #5 clk = ~clk;

    // =====================================================
    // 发送一个 P×Q 矩阵
    // =====================================================
    task send_matrix;
        input [7:0] base;
        integer i, j;
        begin
            @(posedge clk);
            $display("==== Sending Matrix A (25x19) ====");
    
            for (i = 0; i < P; i = i + 1) begin
                for (j = 0; j < Q; j = j + 1) begin
    
                    @(posedge clk);
                    s_axis_i_tvalid <= 1;
                    s_axis_i_tdata  <= base + i*Q + j;   // 模式数据
    
                    if ((i==P-1) && (j==Q-1))
                        s_axis_i_tlast <= 1;
                    else
                        s_axis_i_tlast <= 0;
    
                    while (!s_axis_i_tready) @(posedge clk);
                end
            end
    
            @(posedge clk);
            s_axis_i_tvalid <= 0;
            s_axis_i_tlast  <= 0;
    
            $display("==== Matrix Sending Done ====");
        end
    endtask

    // =====================================================
    // 读取输出
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
    // 主仿真流程
    // =====================================================
    initial begin
        clk = 0;
        rst_n = 1;

        s_axis_i_tvalid = 0;
        s_axis_i_tdata  = 0;
        s_axis_i_tlast  = 0;
        m_axis_o_tready = 1;
        load_control    = 1;

        #20;
        rst_n = 0;
        #20;
        rst_n = 1;

        // =============
        // 输入矩阵 1
        // =============
        $display("=== Load Weight ===");
        send_matrix(8'd1);

        // =============
        // 输入权重
        // =============
        $display("=== Input #1 ===");
        send_matrix(8'd10);
        read_output();

        // =============
        #50;
        load_control    = 0;
        #50;
        // 输入矩阵 #2
        // =============
        $display("=== Input #2 ===");
        send_matrix(8'd50);
        read_output();

        #200;
        $finish;
    end

endmodule