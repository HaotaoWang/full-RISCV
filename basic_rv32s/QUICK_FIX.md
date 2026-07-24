# 快速诊断清单

## 问题：LED 不亮，按复位键也没反应

### ⚠️ 最可能的原因

**复位逻辑问题** - FPGA_Top.v 第 41-42 行:

```verilog
reg [3:0] rst_shift = 4'b0000;  // 上电后默认值为 0000
wire cpu_rst = ~rst_shift[3];   // ~0 = 1 (复位状态!)
```

上电后 `rst_shift[3] = 0`，所以 `cpu_rst = 1`，CPU 处于**持续复位状态**，不会运行！

### 🔍 问题分析

看第 44-49 行的复位同步逻辑:

```verilog
always @(posedge cpu_clk) begin
    rst_shift <= {rst_shift[2:0], sys_rst_n};
    // sys_rst_n=1 (松开) -> 移入1 -> rst_shift 变成 0001, 0011, 0111, 1111
    // sys_rst_n=0 (按下) -> 移入0 -> rst_shift 变成 0000
end
```

**理论上**: 
- 板上复位键有上拉电阻，`sys_rst_n` 默认为 1 (高电平)
- 经过 4 个时钟周期，`rst_shift` 应该变成 `1111`
- 然后 `cpu_rst = ~1 = 0` (运行状态)

**实际问题**:
- 如果板子的复位键没有上拉，或者上拉不稳定
- 或者上电瞬间 `sys_rst_n` 信号不干净
- 可能导致 CPU 卡在复位状态

## 🔧 解决方案

### 方案 1: 修改初始值（最简单）

修改 `fpga/My_Kintex7_RV32_SoC/FPGA_Top.v` 第 41 行:

```verilog
// 修改前:
reg [3:0] rst_shift = 4'b0000;

// 修改后:
reg [3:0] rst_shift = 4'b1111;  // 上电后直接进入运行状态
```

然后重新生成比特流并下载。

### 方案 2: 检查硬件信号

如果你的板子有 LED 可以用来调试，临时添加:

```verilog
assign led[3] = cpu_rst;  // LED3 显示复位状态 (1=复位中, 0=运行)
```

这样就能看到 CPU 是否卡在复位状态。

### 方案 3: 测试更简单的程序

我已经创建了 `simple_led_test.hex`，它直接写 0xF 到 LED，跳过 RAM 读取:

```hex
100200B7    # lui  x1, 0x10020  -> x1 = 0x10020000
0000F137    # lui  x2, 0x0000F  -> x2 = 0x0000F000  
00F0A023    # sw   x2, 0(x1)    -> LED = 0xF (全亮)
0000006F    # jal  x0, 0         -> 死循环
```

修改 `FPGA_Top.v` 第 62 行:

```verilog
// 从:
.INIT_FILE("program.hex")

// 改为:
.INIT_FILE("simple_led_test.hex")
```

## 📝 立即行动

### 1. 先确认硬件

- [ ] FPGA 板已上电
- [ ] USB/JTAG 已连接
- [ ] 比特流下载成功 (DONE LED 亮)
- [ ] 尝试按复位键 (如果有的话)

### 2. 快速修复 - 修改复位初始值

```verilog
reg [3:0] rst_shift = 4'b1111;  // 改这一行
```

### 3. 重新生成并下载

在 Vivado 中:
1. 打开 `RV32_Kintex7_SoC.xpr`
2. 修改 `FPGA_Top.v`
3. Generate Bitstream
4. Program Device

## 🎯 预期结果

修复后:
- LED[3:0] 应该显示 **0x7** (0111 二进制)
- 即 LED0, LED1, LED2 亮，LED3 灭

如果使用 `simple_led_test.hex`:
- LED[3:0] 应该显示 **0xF** (1111 二进制)
- 即所有 LED 都亮

## 💡 其他可能性

如果修改后还是不亮:

1. **时钟问题**: 检查 `sys_clk` 是否正确连接到板载时钟
2. **约束文件**: 检查 `Kintex_MK160FA.xdc` 引脚约束是否正确
3. **LED 极性**: 确认 LED 是高电平有效还是低电平有效
4. **时序违例**: 查看时序报告，确认 WNS > 0

## 📊 验证程序正确性

你的 program.hex 逻辑是对的:
- ✓ 正确设置 MMIO 地址 (0x10020000)
- ✓ 从 RAM 读取数据 (lw 指令)
- ✓ 写入 LED 寄存器
- ✓ MMIO_Interface.v 地址映射正确

问题不在程序，而在**硬件初始化**。
