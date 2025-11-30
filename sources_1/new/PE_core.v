// Engineer:      Zhenhang Qin
// Create Date:   2025/11/24
// Design Name:   PE_core
// Module Name:   PE_Core
// Description:   用于计算两个8位有符号数相乘，将输入传递给下一个单元，并累加结果，支持WS和OS两种模式
// input:
//      clk: 时钟信号
//      rst_n: 复位信号'
//      drain: 结果输出使能信号,高电平时OS状态将结果输出
//      data_flow: 模式选择信号，1为WS模式，0为OS模式
//      load: 权重加载使能信号,高电平时将data_in输入作为权重输入
//      left: 水平输入A
//      up: 垂直输入，Load模式下为权重，计算模式下为上方传来的Partial Sum
// output:
//      right: 水平输出A
//      down: 垂直输出，Load模式下传递权重，计算模式下输出累加结果
//      ps_reg: OS模式下输出累加结果

`timescale 1ns / 1ps
`timescale 1ns / 1ps

module PE_Core #(
    parameter DATA_WIDTH = 8
)(
    input clk,
    input rst_n,
    input data_flow,            // 1: WS, 0: OS
    input load,                 // WS模式加载权重
    input drain,                // OS模式结果输出使能
    input signed [DATA_WIDTH-1:0] left,      
    input signed [2*DATA_WIDTH-1:0] up,  
    
    output reg signed [DATA_WIDTH-1:0] right,     
    output reg signed [2*DATA_WIDTH-1:0] down
);

    reg signed [DATA_WIDTH-1:0] weight_reg; 
    reg signed [2*DATA_WIDTH-1:0] ps_reg;   
    wire signed [2*DATA_WIDTH-1:0] temp_result;

    // 定义实际进入乘法器B端口的信号
    // WS模式: 用本地存好的 weight_reg
    // OS模式: 直接用流进来的 up (截取低8位)，消除1拍延迟
    wire signed [DATA_WIDTH-1:0] mult_input_b;
    assign mult_input_b = (data_flow) ? weight_reg : up[DATA_WIDTH-1:0];

    // 实例化乘法器
    multiplier u_multiplier(
        .clk(clk),
        .CE(1'b1),
        .SCLR(!rst_n),
        .A(left),
        .B(mult_input_b), // 使用选择后的信号
        .P(temp_result)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            right      <= 0;
            down       <= 0;
            weight_reg <= 0;
            ps_reg     <= 0;
        end else begin
            // 1. 水平数据透传 (适用所有模式)
            right <= left;

            if (data_flow) begin
                // ========================
                // WS Mode (Weight Stationary)
                // ========================
                if (load) begin
                    // 权重加载与传递
                    weight_reg <= up[DATA_WIDTH-1:0];
                    down       <= up;
                end else begin
                    // 权重不动，部分和流动
                    // down = 上方的部分和 + 当前乘积
                    down <= up + temp_result;
                end
            end else begin
                // ========================
                // OS Mode (Output Stationary)
                // ========================
                // 权重必须流动 (传递给下方PE)
                down <= up; 
                if (drain) begin
                    // 结算模式：停止累加，将结果通过 down 吐出去
                    // 此时 down 被借用来传输结果，不再传权重
                    down <= ps_reg; 
                    ps_reg <= 0; // 清零，为下一轮做准备
                end else begin
                    // 累加模式
                    ps_reg <= ps_reg + temp_result;
                end
            end
        end
    end
endmodule

module multiplier
#(parameter DATA_WIDTH = 8)
(
    input clk,CE,SCLR,
    input signed [DATA_WIDTH-1:0] A,
    input signed [DATA_WIDTH-1:0] B,
    output reg   [2*DATA_WIDTH-1:0] P
);
    always@(posedge clk or posedge SCLR)
        begin
            if(SCLR)
                P<=0;
            else
            if(CE)
                P<=A*B;
            else
                P<=P;
        end
endmodule
