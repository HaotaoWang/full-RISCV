# FPGA 上板问题诊断与解决方案

## 问题现象
- ✅ 串口硬件正常 (COM5 测试通过)
- ✅ 板子型号确认: MK160TFA (XC7K160T-2FFG676)
- ⚠️ LED 全亮无变化
- ⚠️ 按复位有变化 (说明复位信号工作)
- ❌ 串口能打开但没有输出

## 根本原因分析

### 1. **时钟问题** ⚠️ 高度可疑
查看 `FPGA_Top.v:66` 发现：
```verilog
.INIT_FILE("mmu_test.hex")
```

这个程序是 **MMU 虚拟内存测试程序**，需要运行在 S-Mode (Supervisor Mode)，这是一个非常复杂的程序！

### 2. **XDC 约束问题** ⚠️
查看 `Kintex_MK160FA.xdc:35-36`，UART 引脚被注释掉了：
```tcl
# set_property -dict { PACKAGE_PIN V24   IOSTANDARD LVCMOS33 } [get_ports { uart_rx }]
# set_property -dict { PACKAGE_PIN U22   IOSTANDARD LVCMOS33 } [get_ports { uart_tx }]
```

但是 `FPGA_Top.v` 中**没有 UART 端口声明**！这意味着：
- CPU 内部可能在发送 UART 数据
- 但是 **UART 信号没有连接到物理引脚**
- 串口软件能打开，但接收不到任何数据

### 3. **LED 全亮的原因**
如果 CPU 卡在某个状态，`mmio_led` 可能输出 `4'b1111` (全亮)

---

## 解决方案

### 方案 1: 使用简单的 LED 测试程序 (推荐优先尝试)

#### 步骤 1: 修改 FPGA_Top.v 使用简单程序
```bash
# 修改第 66 行，从 mmu_test.hex 改为 led_test_axi.hex
sed -i 's/\.INIT_FILE("mmu_test\.hex")/\.INIT_FILE("led_test_axi.hex")/' basic_rv32s/fpga/My_Kintex7_RV32_SoC/FPGA_Top.v
```

或手动编辑 `basic_rv32s/fpga/My_Kintex7_RV32_SoC/FPGA_Top.v` 第 66 行：
```verilog
// 修改前:
.INIT_FILE("mmu_test.hex")

// 修改后:
.INIT_FILE("led_test_axi.hex")
```

#### 步骤 2: 重新生成比特流
在 Vivado 中：
1. 打开项目
2. 点击 "Generate Bitstream"
3. 等待综合和实现完成
4. 下载到 FPGA

---

### 方案 2: 添加 UART 物理连接 (如果需要串口输出)

#### 修改 1: 给 FPGA_Top.v 添加 UART 端口

编辑 `basic_rv32s/fpga/My_Kintex7_RV32_SoC/FPGA_Top.v`，修改顶层模块定义：

```verilog
module FPGA_Top (
    input  wire       sys_clk,     // 板载系统时钟
    input  wire       sys_rst_n,   // 板载复位按键
    
    // 新增 UART 端口
    input  wire       uart_rx,     // UART 接收 (预留)
    output wire       uart_tx,     // UART 发送

    output wire [3:0] led          // 板载 LED x4
);
```

#### 修改 2: 连接 UART 信号

在 `FPGA_Top.v` 中找到 SoC 实例化部分，添加 UART 连接：

```verilog
// 在模块顶部添加 UART 相关信号
wire [7:0]  mmio_uart_tx_data;
wire        mmio_uart_tx_start;

// 实例化一个简单的 UART 发送器
uart_tx_simple #(
    .CLK_FREQ(50_000_000),  // CPU 时钟 50MHz (100MHz/2)
    .BAUD_RATE(115200)
) uart_transmitter (
    .clk(cpu_clk),
    .rst(cpu_rst),
    .tx_data(mmio_uart_tx_data),
    .tx_start(mmio_uart_tx_start),
    .tx(uart_tx),
    .busy()  // 可以连接到 UART_busy，这里暂时悬空
);
```

#### 修改 3: 取消注释 XDC 约束

编辑 `basic_rv32s/fpga/My_Kintex7_RV32_SoC/Kintex_MK160FA.xdc`，取消注释：

```tcl
# 取消这两行的注释
set_property -dict { PACKAGE_PIN V24   IOSTANDARD LVCMOS33 } [get_ports { uart_rx }]
set_property -dict { PACKAGE_PIN U22   IOSTANDARD LVCMOS33 } [get_ports { uart_tx }]
```

---

## 快速验证方案：最小 LED 测试

如果上述方案仍然有问题，可以创建一个**最简单的测试**来验证硬件：

### 创建超简单的 LED 闪烁测试

```verilog
// 保存为 basic_rv32s/fpga/My_Kintex7_RV32_SoC/simple_blink.v
module simple_blink (
    input  wire sys_clk,
    input  wire sys_rst_n,
    output reg  [3:0] led
);
    reg [27:0] counter;
    
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            counter <= 0;
            led <= 4'b0001;
        end else begin
            counter <= counter + 1;
            if (counter == 28'd50_000_000) begin  // 0.5秒 @ 100MHz
                counter <= 0;
                led <= {led[2:0], led[3]};  // 循环左移
            end
        end
    end
endmodule
```

在 Vivado 中：
1. 将 `simple_blink.v` 添加到项目
2. 设置为顶层模块 (Set as Top)
3. 生成比特流并下载

如果这个能工作，说明：
- ✅ 时钟正常
- ✅ 复位正常
- ✅ LED 输出正常
- 问题出在 CPU 或程序上

---

## 推荐的调试顺序

1. **先尝试方案 1** - 切换到 `led_test_axi.hex`，这是最简单的测试
2. **如果 LED 还是不变化** - 使用"快速验证方案"的 simple_blink 测试硬件
3. **硬件验证通过后** - 再添加 UART 支持 (方案 2)

---

## 当前配置信息

- **CPU 时钟**: 100MHz 输入 → 50MHz CPU (二分频)
- **内存大小**: 64KB (RAM_ADDR_WIDTH=16)
- **当前程序**: mmu_test.hex (MMU 测试，非常复杂)
- **UART 波特率**: 115200 (如果添加 UART 模块)

---

## 下一步行动

请告诉我你想先尝试哪个方案：
1. 我帮你修改代码切换到简单的 LED 测试
2. 我帮你创建最简单的硬件验证程序
3. 我帮你添加完整的 UART 支持

选择一个方案，我会立即帮你实施！
