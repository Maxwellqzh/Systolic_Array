// Engineer:      Zhenhang Qin
// Create Date:   2025/11/24
// Design Name:   PE_Status_Controller
// Module Name:   PE_Status_Controller
// Description:   用于控制PE_Array的计算状态，支持os和ws模式
// input:
//      clk: 时钟信号
//      rst_n: 复位信号
//      en: 外部输入使能
//      data_flow: 数据流模式选择信号,1为WS模式,0为OS模式
// output:
//      drain_out: 输出给 PE Array 的 drain 信号
//      valid_out: 全局输出有效信号

`timescale 1ns / 1ps

module PE_Status_Controller #(
    parameter ROWS = 8,
    parameter COLS = 8
)(
    input clk,
    input rst_n,
    input en,            // 外部输入使能
    input data_flow,     // 0: OS, 1: WS
    
    output reg drain_out, // 输出给 PE Array 的 drain 信号
    output reg valid_out      // 全局输出有效信号
);

    // ===============================================================
    // 逻辑 1: OS 模式的状态机控制 (Batch Processing)
    // ===============================================================
    localparam S_IDLE      = 0;
    localparam S_COMPUTE   = 1;
    localparam S_WAIT_CALC = 2; // 等待最后一个数据算完
    localparam S_DRAINING  = 3; // 结果移出阶段

    reg [2:0] state, next_state;
    reg [7:0] cnt;
    reg os_valid; // OS 模式下的 valid

    // OS 模式参数
    // 等待时间：输入结束后，最后一个 A 数据传到最右列需要 COLS 个周期
    localparam OS_WAIT_CYCLES = COLS;
    // 输出时间：将 ROWS 行结果逐行移出需要 ROWS 个周期,总共需要 ROWS + COLS 个周期
    localparam OS_OUTPUT_CYCLES = ROWS + COLS;

    // FSM Update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_IDLE;
        else        state <= next_state;
    end

    // FSM Logic
    always @(*) begin
        next_state = state;
        case(state)
            S_IDLE: begin
                if(en) next_state = S_COMPUTE;
            end
            S_COMPUTE: begin
                // 检测下降沿：如果当前 en 为低 (假设外部已拉低)，或者根据逻辑检测
                // 这里简单处理：如果 en 拉低，进入等待
                if(!en) next_state = S_WAIT_CALC; 
            end
            S_WAIT_CALC: begin
                if(cnt == OS_WAIT_CYCLES - 1) next_state = S_DRAINING;
            end
            S_DRAINING: begin
                if(cnt == OS_OUTPUT_CYCLES - 1) next_state = S_IDLE;
            end
            default: next_state = S_IDLE;
        endcase
    end

    // Output & Counter Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 0;
            drain_out <= 0;
            os_valid <= 0;
        end else begin
            case(next_state)
                S_IDLE, S_COMPUTE: begin
                    cnt <= 0;
                    drain_out <= 0;
                    os_valid <= 0;
                end
                S_WAIT_CALC: begin
                    cnt <= cnt + 1;
                    drain_out <= 0;
                    os_valid <= 0;
                end
                S_DRAINING: begin
                    cnt <= cnt + 1;
                    // OS 模式下，Drain 阶段拉高 drain 信号和 valid 信号
                    drain_out <= 1; 
                    os_valid <= 1;
                end
            endcase
        end
    end

    // ===============================================================
    // 逻辑 2: WS 模式的延迟链控制 (Streaming Processing)
    // ===============================================================
    // WS 模式下，结果是流式的。Valid 信号应该是输入 en 的延迟版。
    // 总延迟 = 垂直流水线(ROWS) 
    localparam WS_LATENCY = ROWS; // [修改点] 移除 COLS 的延迟
    
    reg [WS_LATENCY-1:0] ws_valid_shift;
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ws_valid_shift <= 0;
        end else begin
            ws_valid_shift <= {ws_valid_shift[WS_LATENCY-2:0], en};
        end
    end
    
    wire ws_valid = ws_valid_shift[WS_LATENCY-1];

    // ===============================================================
    // 最终输出选择
    // ===============================================================
    // 多打一拍，valid信号要比drain信号晚一个周期
    // 如果是 WS 模式，drain_out 强制为 0 (自然流动)，valid 用延迟链
    // 如果是 OS 模式，用 FSM 控制
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            valid_out <= 0;
        end else begin
            valid_out <= (data_flow) ? ws_valid : os_valid;
        end
    end
endmodule