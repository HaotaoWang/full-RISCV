# LED 不亮问题诊断报告

## 你的程序分析

### program.hex 指令序列

```
地址      指令值        汇编指令              说明
----      --------      --------             ----
0x00:     10020237      lui x4, 0x10020      x4 = 0x10020000 (LED MMIO 基地址)
0x04:     000002B7      lui x5, 0x00000      x5 = 0x00000000 (RAM 基地址)
0x08:     0042A303      lw  x6, 4(x5)        x6 = RAM[0x04] = 0x000002B7
0x0C:     00622023      sw  x6, 0(x4)        mem[0x10020000] = x6 (写入 LED)
0x10:     0000006F      jal x0, 0            死循环在地址 0x10
```

### 执行流程

1. **设置 MMIO 地址**: x4 = 0x10020000 (LED 寄存器地址)
2. **设置 RAM 地址**: x5 = 0x00000000
3. **从 RAM 读取**: x6 = RAM[0x04] = 0x000002B7 (这是第二条指令)
4. **写入 LED**: LED[3:0] = x6[3:0] = 0xB7 & 0xF = **0x7** (二进制 0111)
5. **死循环**: 程序停在地址 0x10

### 预期结果

LED 应该显示: **0x7** (LED0=1, LED1=1, LED2=1, LED3=0)

## LED 不亮的可能原因

### 1. 复位信号问题 ⚠️ (最可能)

从 FPGA_Top.v 第 42 行可以看到:

```verilog
reg [3:0] rst_shift = 4'b0000;  // 上电后默认不复位
wire cpu_rst = ~rst_shift[3];   // rst_shift=0000 -> cpu_rst=1 (复位状态!)
```

**问题**: 上电后 `rst_shift = 0000`，导致 `cpu_rst = 1`（复位状态），CPU 不会运行！

**解决方案**: 需要按下并释放复位键 (sys_rst_n) 让 CPU 启动。

### 2. 死循环地址错误 ⚠️

第 4 条指令 `0000006F` (jal x0, 0) 会跳转到 **当前 PC + 0 = 0x10**，死循环在 0x10。

但是 RAM 地址 0x10 可能没有有效指令，会导致 CPU 异常。

### 3. MMIO 地址映射验证 ✓

从 MMIO_Interface.v 确认:
- LED_ADDR = 0x10020000 ✓
- 写入逻辑正确 ✓

### 4. RAM 初始化验证 ✓

从 FPGA_Top.v 第 62 行:
```verilog
.INIT_FILE("program.hex")
```

这个参数传递给 axil_ram_init，会正确加载 program.hex ✓

## 解决方案

### 方案 1: 修复复位逻辑（推荐）

修改 `FPGA_Top.v` 第 41-42 行：

```verilog
// 修改前:
reg [3:0] rst_shift = 4'b0000;
wire cpu_rst = ~rst_shift[3];

// 修改后:
reg [3:0] rst_shift = 4'b1111;  // 上电后默认为运行状态
wire cpu_rst = ~rst_shift[3];   // rst_shift=1111 -> cpu_rst=0 (运行)
```

### 方案 2: 修复死循环问题

修改 `program.hex` 让死循环跳回地址 0x10:

```hex
10020237
000002B7
0042A303
00622023
FE5FF06F
```

最后一条改为: `fe5ff06f` = `jal x0, -28` (跳转到 0x10-28=-0x1C, 但实际会跳到 0x10+(-0x1C)=PC+offset)

**更简单的方法 - 跳回开头**:

```hex
10020237
000002B7
0042A303
00622023
FF1FF06F
```

最后一条: `ff1ff06f` = `jal x0, -16` (跳回 0x0C，重复写 LED)

### 方案 3: 创建更简单的测试程序

创建一个直接写 LED 的程序:

```hex
100200B7
00000137
0070A023
0000006F
```

指令说明:
```
lui  x1, 0x10020       # x1 = 0x10020000 (LED 地址)
lui  x2, 0x00000       # x2 = 0x00000000
sw   x0, 7(x1)         # 直接写 7 到 LED
jal  x0, 0             # 死循环
```

## 立即测试步骤

### 步骤 1: 检查硬件

1. 确认 FPGA 板已上电
2. 确认比特流已下载 (DONE LED 亮)

### 步骤 2: 尝试复位

1. **按下复位键** (sys_rst_n)
2. **松开复位键**
3. 观察 LED 是否变化

如果 LED 还是不亮，说明是复位逻辑问题。

### 步骤 3: 修改代码重新综合

如果按复位也不行，需要修改 `FPGA_Top.v` 的复位逻辑并重新生成比特流。

## 调试建议

### 使用 Vivado ILA 调试

添加 Integrated Logic Analyzer 监控:
- `cpu_rst` - 应该是 0 (运行状态)
- `cpu_clk` - 应该在翻转
- `mmio_led` - 应该变为 0x7
- `retire_instruction` - 当前执行的指令

### 检查时序

查看时序报告:
```
fpga/Vivado_Project/RV32_Kintex7_SoC.runs/impl_1/FPGA_Top_timing_summary_routed.rpt
```

确认没有时序违例 (WNS > 0)。

## 总结

**最可能的原因**: 上电后 CPU 处于复位状态，需要按复位键启动。

**快速解决方法**: 
1. 按下并释放板上的复位键
2. 如果不行，修改 FPGA_Top.v 的 rst_shift 初始值为 4'b1111

**验证方法**: 使用 Vivado ILA 或 chipscope 监控内部信号。
