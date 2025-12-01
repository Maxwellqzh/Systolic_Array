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
//// ====================================
//// 参数
//// ====================================
//localparam M = 8;
//localparam N = 8;
//localparam L = 8;
//localparam DW = 8;
//localparam OW = 16;
//localparam P  = 4;
//localparam Q  = 4;

//// ====================================
//// DUT 端口
//// ====================================
//reg clk;
//reg rst_n;

//reg  [DW-1:0] s_axis_a_tdata;
//reg           s_axis_a_tvalid;
//wire          s_axis_a_tready;
//reg           s_axis_a_tlast;

//reg  [DW-1:0] s_axis_b_tdata;
//reg           s_axis_b_tvalid;
//wire          s_axis_b_tready;
//reg           s_axis_b_tlast;

//wire [OW-1:0] m_axis_c_tdata;
//wire          m_axis_c_tvalid;
//reg           m_axis_c_tready;
//wire          m_axis_c_tlast;


//// ====================================
//// DUT 实例化
//// ====================================
//AXIS_SA_OS #(
//    .M(M), .N(N), .L(L),
//    .DW(DW), .OW(OW),
//    .P(P), .Q(Q)
//) dut (
//    .clk(clk),
//    .rst_n(rst_n),

//    .s_axis_a_tdata (s_axis_a_tdata),
//    .s_axis_a_tvalid(s_axis_a_tvalid),
//    .s_axis_a_tready(s_axis_a_tready),
//    .s_axis_a_tlast (s_axis_a_tlast),

//    .s_axis_b_tdata (s_axis_b_tdata),
//    .s_axis_b_tvalid(s_axis_b_tvalid),
//    .s_axis_b_tready(s_axis_b_tready),
//    .s_axis_b_tlast (s_axis_b_tlast),

//    .m_axis_c_tdata (m_axis_c_tdata),
//    .m_axis_c_tvalid(m_axis_c_tvalid),
//    .m_axis_c_tready(m_axis_c_tready),
//    .m_axis_c_tlast (m_axis_c_tlast)
//);


//// ====================================
//// 时钟
//// ====================================
//always #5 clk = ~clk;  // 100MHz
//always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            m_axis_c_tready <= 1;
//        end
//        else begin
//            if (m_axis_c_tvalid && m_axis_c_tready && m_axis_c_tlast)
//                m_axis_c_tready <= 0;   // 接收最后一个数据后停止 ready
//        end
//    end
//// ====================================
//// 初始化任务
//// ====================================
//initial begin
//    clk = 0;
//    rst_n = 1;

//    s_axis_a_tdata  = 0;
//    s_axis_a_tvalid = 0;
//    s_axis_a_tlast  = 0;

//    s_axis_b_tdata  = 0;
//    s_axis_b_tvalid = 0;
//    s_axis_b_tlast  = 0;

//    m_axis_c_tready = 1;  // 允许 DUT 输出（你的系统暂时不会输出）

//    #20 rst_n = 0;
//    #20 rst_n = 1;

//    // 送入 A
//    send_A_matrix();

//    // 等待一段时间
//    #100;

//    // 送入 B
//    send_B_matrix();

//    #10000;

//    $finish;
//end



//// =======================================================
//// 任务：按行连续发送 A（8×8）
//// =======================================================
//task send_A_matrix;
//    integer i, j;
//    begin
//        @(posedge clk);
//        $display("Sending Matrix A ...");

//        for (i = 0; i < M; i = i + 1) begin
//            for (j = 0; j < N; j = j + 1) begin
//                @(posedge clk);
//                s_axis_a_tvalid <= 1;
//                s_axis_a_tdata  <= (i*10 + j);  // 简单可见的模式数据

//                if (i==M-1 && j==N-1)
//                    s_axis_a_tlast <= 1;
//                else
//                    s_axis_a_tlast <= 0;
//            end
//        end

//        @(posedge clk);
//        s_axis_a_tvalid <= 0;
//        s_axis_a_tlast  <= 0;
//    end
//endtask



//// =======================================================
//// 任务：按行连续发送 B（8×8）
//// =======================================================
//task send_B_matrix;
//    integer i, j;
//    begin
//        @(posedge clk);
//        $display("Sending Matrix B ...");

//        for (i = 0; i < N; i = i + 1) begin
//            for (j = 0; j < L; j = j + 1) begin
//                @(posedge clk);
//                s_axis_b_tvalid <= 1;
//                s_axis_b_tdata  <= (i*10 + j + 1);  // B 用不同模式

//                if (i==N-1 && j==L-1)
//                    s_axis_b_tlast <= 1;
//                else
//                    s_axis_b_tlast <= 0;
//            end
//        end

//        @(posedge clk);
//        s_axis_b_tvalid <= 0;
//        s_axis_b_tlast  <= 0;
//    end
//endtask


//endmodule

    // ====================================
    // 参数
    // ====================================
    localparam M = 25;
    localparam N = 19;
    localparam L = 17;
    
    localparam DW = 8;
    localparam OW = 16;
    
    localparam P  = 8;
    localparam Q  = 8;
    
    
    // ====================================
    // DUT 端口
    // ====================================
    reg clk;
    reg rst_n;
    
    reg  [DW-1:0] s_axis_a_tdata;
    reg           s_axis_a_tvalid;
    wire          s_axis_a_tready;
    reg           s_axis_a_tlast;
    
    reg  [DW-1:0] s_axis_b_tdata;
    reg           s_axis_b_tvalid;
    wire          s_axis_b_tready;
    reg           s_axis_b_tlast;
    
    wire [OW-1:0] m_axis_c_tdata;
    wire          m_axis_c_tvalid;
    reg           m_axis_c_tready;
    wire          m_axis_c_tlast;
    
    
    // ====================================
    // DUT 实例化
    // ====================================
    AXIS_SA_OS #(
        .M(M), .N(N), .L(L),
        .DW(DW), .OW(OW),
        .P(P), .Q(Q)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        
        .s_axis_a_tdata (s_axis_a_tdata),
        .s_axis_a_tvalid(s_axis_a_tvalid),
        .s_axis_a_tready(s_axis_a_tready),
        .s_axis_a_tlast (s_axis_a_tlast),
    
        .s_axis_b_tdata (s_axis_b_tdata),
        .s_axis_b_tvalid(s_axis_b_tvalid),
        .s_axis_b_tready(s_axis_b_tready),
        .s_axis_b_tlast (s_axis_b_tlast),
    
        .m_axis_c_tdata (m_axis_c_tdata),
        .m_axis_c_tvalid(m_axis_c_tvalid),
        .m_axis_c_tready(m_axis_c_tready),
        .m_axis_c_tlast (m_axis_c_tlast)
    );
    
    
    // ====================================
    // 时钟 100MHz
    // ====================================
    always #5 clk = ~clk;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axis_c_tready <= 1;
        end
        else begin
            if (m_axis_c_tvalid && m_axis_c_tready && m_axis_c_tlast)
                m_axis_c_tready <= 0;   // 接收最后一个数据后停止 ready
        end
    end
    
    // ====================================
    // 初始化
    // ====================================
    initial begin
        clk = 0;
        rst_n = 0;
    
        s_axis_a_tdata  = 0;
        s_axis_a_tvalid = 0;
        s_axis_a_tlast  = 0;
    
        s_axis_b_tdata  = 0;
        s_axis_b_tvalid = 0;
        s_axis_b_tlast  = 0;
    
        m_axis_c_tready = 1;  // 允许输出
    
        #50 rst_n = 1;
    
        // 送入 A
        send_A_matrix();
    
        #100;
    
        // 送入 B
        send_B_matrix();
        
        
    
        #30000;
    
        $finish;
    end
    
    
    // =======================================================
    // 任务：按行连续发送 A（25×19）
    // =======================================================
    task send_A_matrix;
        integer i, j;
        begin
            @(posedge clk);
            $display("==== Sending Matrix A (25x19) ====");
    
            for (i = 0; i < M; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
    
                    @(posedge clk);
                    s_axis_a_tvalid <= 1;
                    s_axis_a_tdata  <= (i*1 + j);   // 模式数据
    
                    if ((i==M-1) && (j==N-1))
                        s_axis_a_tlast <= 1;
                    else
                        s_axis_a_tlast <= 0;
    
                    while (!s_axis_a_tready) @(posedge clk);
                end
            end
    
            @(posedge clk);
            s_axis_a_tvalid <= 0;
            s_axis_a_tlast  <= 0;
    
            $display("==== Matrix A Sending Done ====");
        end
    endtask
    
    
    
    // =======================================================
    // 任务：按行连续发送 B（19×17）
    // =======================================================
    task send_B_matrix;
        integer i, j;
        begin
            @(posedge clk);
            $display("==== Sending Matrix B (19x17) ====");
    
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < L; j = j + 1) begin
    
                    @(posedge clk);
                    s_axis_b_tvalid <= 1;
                    s_axis_b_tdata  <= (i*2 + j + 1);   // 与 A 不同的模式
    
                    if ((i==N-1) && (j==L-1))
                        s_axis_b_tlast <= 1;
                    else
                        s_axis_b_tlast <= 0;
    
                    while (!s_axis_b_tready) @(posedge clk);
                end
            end
    
            @(posedge clk);
            s_axis_b_tvalid <= 0;
            s_axis_b_tlast  <= 0;
    
            $display("==== Matrix B Sending Done ====");
        end
    endtask
endmodule

