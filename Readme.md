### 2.3 存在的问题与未来研究方向

##### 2.3.1 从静态配置到运行时自适应架构

WS、OS、RS 等传统的固定数据流难以适应多样化负载，目前的使用场景更需要动态可重构的数据流架构，通过监测数据复用模式动态选择OS/WS/RS数据流。未来可进一步结合强化学习优化决策，为计算提供弹性加速能力。 例如 Eyeriss v2 [13] 采用了这种策略，使用的层次化 mesh 片上网络可以适应不同数据类型的不同带宽与数据复用需求，提高计算资源利用率。

##### 2.3.2 **从离线优化到算法-硬件在线协同**

现有硬件缺乏对算法精度弹性的利用。HMSA [11] 中提出了异构PE 的思想，从**数值位宽**的角度实现精度弹性计算。这一思路可以拓展至**层间自适应精度分配**，例如敏感层16-bit，冗余层8-bit 等。这种设计要求PE支持**动态精度重配置**（如运行时切换乘法器宽度），并要求编译器像PolySA[7]那样进行敏感度驱动的自动映射，形成"算法分析-硬件配置-编译器生成"的闭环。

##### 2.3.3 **平面集成到内存层次根本革命**

为突破"内存墙"，可以探索**近内存计算与脉动阵列的异构集成**。将部分计算嵌入存储层次，减少数据搬运。这与BRAMAC的"计算向存储靠近"理念同源，但可以将**FPGA BRAM**进一步推向**3D堆叠DRAM/ReRAM**，实现更广义的PIM，通过PE阵列与存储层次协同设计，避免传统架构中存储与计算分离导致的频繁访存。3D堆叠可通过**Through-Silicon Vias (TSVs)** 实现垂直垂直方向的高速通信，将平面脉动阵列的**水平数据流**扩展为**垂直数据流**，通过TSV实现权重从上层DRAM直达各层PE，根本缓解边缘PE带宽瓶颈。

## 第三章：可以考虑的实现方案      

### 3.1 方案：动态精度可重构脉动阵列

##### 设计目标

- 在现有8×8 PE阵列基础上，增加**动态精度切换能力**（支持8位/16位模式）
- 实现**运行时数据流可配置**（OS/WS两种模式）
- 提供**自动化配置接口**，支持不同层类型自动映射

##### PE 参考方案：双精度乘法器 + 可配置累加器

```Verilog
module PE_reconfig (
  input [7:0]  A_in_8b,    // 激活输入
  input [7:0]  W_in_8b,    // 权重输入
  input [15:0] A_in_16b,   // 16位模式激活
  input [15:0] W_in_16b,   // 16位模式权重
  input [31:0] psum_in,    // 部分和输入
  input        precision,  // 0:8位, 1:16位
  input        dataflow,   // 0:OS, 1:WS
  output [31:0] psum_out   // 部分和输出
);

  wire [31:0] mult_result;
  
  // 精度可配置乘法器
  assign mult_result = (precision == 0) ? 
                      {24'b0, A_in_8b * W_in_8b} : 
                      A_in_16b * W_in_16b;
  
  // 数据流可配置累加
  assign psum_out = (dataflow == 0) ? 
                   mult_result :           // OS: 重新开始
                   psum_in + mult_result;  // WS: 累加
  
endmodule
```

##### 数据流参考方案：OS/WS 模式切换

```verilog
always @(*) begin
  if (dataflow == 0) begin // OS模式
    // 激活横向传播，权重纵向传播
    A_out = A_in;
    W_out = W_in;
    psum_out = local_psum; // 每个PE独立输出
  end else begin // WS模式
    // 激活纵向传播，权重固定在PE中
    A_out = A_in;
    W_out = W_reg; // 权重寄存器保持
    psum_out = psum_in + mult_result; // 部分和横向传播
  end
end
```

##### 配置字参考方案

```verilog
# 伪代码：根据层类型自动生成配置
def auto_config(layer_type, input_precision):
    if layer_type == "CONV1":
        return {"precision": 1, "dataflow": 0}  # 16位, OS
    elif layer_type == "DW_CONV":
        return {"precision": 0, "dataflow": 1}  # 8位, WS
    elif layer_type == "FC":
        return {"precision": 1, "dataflow": 0}  # 16位, OS
    else:
        return {"precision": 0, "dataflow": 0}  # 默认
```

##### 控制模块参考方案

```Verilog
module DPR_SA_Controller (
  input clk, reset,
  input [1:0] layer_type,      // 层类型输入
  input [1:0] precision_hint,  // 精度提示
  output reg [7:0] config_bus  // 配置总线
);

  // 配置查找表
  always @(*) begin
    case (layer_type)
      2'b00: config_bus = {precision_hint, 1'b0, 5'b0}; // CONV: OS
      2'b01: config_bus = {2'b00, 1'b1, 5'b0};          // DW: WS
      2'b10: config_bus = {precision_hint, 1'b0, 5'b0}; // FC: OS
      default: config_bus = 8'b0;
    endcase
  end
  
  // 配置分发逻辑
  always @(posedge clk) begin
    if (reset) 
      // 复位为默认8位OS模式
      pe_config <= 64'b0;
    else
      // 广播配置到所有PE
      for (int i=0; i<64; i=i+1)
        pe_config[i] <= config_bus;
  end

endmodule
```

##### 实验数据集参考：CIFAR-10

##### 实验网络模型：Mini-VGG + Depthwise Conv

```python
class TestNet(nn.Module):
    def __init__(self):
        super(TestNet, self).__init__()
        # CONV1: 精度敏感层
        self.conv1 = nn.Conv2d(3, 32, 3, padding=1)  # 16位
        # DW_CONV: 计算密集型
        self.dw_conv = nn.Conv2d(32, 32, 3, groups=32, padding=1)  # 8位  
        # CONV2: 精度敏感层
        self.conv2 = nn.Conv2d(32, 64, 3, padding=1)  # 16位
        # FC: 精度敏感层
        self.fc = nn.Linear(64*8*8, 10)  # 16位
        
    def forward(self, x):
        x = F.relu(self.conv1(x))
        x = F.relu(self.dw_conv(x))
        x = F.max_pool2d(x, 2)
        x = F.relu(self.conv2(x))
        x = F.max_pool2d(x, 2)
        x = x.view(x.size(0), -1)
        x = self.fc(x)
        return x
```

##### 实验对比方案参考

- **Baseline 1**: 固定8位精度 + OS数据流
- **Baseline 2**: 固定16位精度 + OS数据流
- **Baseline 3**: 固定8位精度 + WS数据流
- **本设计**: 动态精度 + 自适应数据流

##### 评价指标参考

- 数据吞吐量 + 每秒运算次数
- PE 利用率 + 数据复用率