# Vivado 工程位置说明

## 📁 工程文件位置

你的 RISC-V CPU 有 3 个 Vivado 工程：

### 1. **RV32_Kintex7_SoC** （推荐使用）
**路径**: `D:\riscv\basic_rv32s\fpga\Vivado_Project\RV32_Kintex7_SoC.xpr`

**最后修改**: 2026-07-25  
**用途**: 完整的 SoC 工程，支持 RT-Thread  
**目标板**: Kintex-7 系列 FPGA

**✅ 这是你应该使用的工程！**

### 2. RV32I46F5SP_Dhrystone
**路径**: `D:\riscv\basic_rv32s\fpga\RV32I46F5SP_Dhrystone\RV32I46F5SP_Dhrystone.xpr`

**用途**: Dhrystone 性能测试
**说明**: 专门用于性能基准测试

### 3. RV32I46F5SP_MMIO_Dhrystone
**路径**: `D:\riscv\basic_rv32s\fpga\RV32I46F5SP_MMIO_Dhrystone\RV32I46F5SP_MMIO_Dhrystone.xpr`

**用途**: 带 MMIO 的 Dhrystone 测试
**说明**: 另一个测试工程

---

## 🚀 打开工程的方法

### 方法 1: 通过 Vivado GUI（推荐）

**Windows 文件管理器**：
1. 打开目录：`D:\riscv\basic_rv32s\fpga\Vivado_Project\`
2. 双击文件：`RV32_Kintex7_SoC.xpr`
3. Vivado 会自动启动并打开工程

### 方法 2: 通过命令行

**PowerShell**：
```powershell
cd D:\riscv\basic_rv32s\fpga\Vivado_Project
vivado RV32_Kintex7_SoC.xpr
```

**Bash (Git Bash)**：
```bash
cd /d/riscv/basic_rv32s/fpga/Vivado_Project
vivado RV32_Kintex7_SoC.xpr &
```

### 方法 3: 通过 Vivado 内部

1. 启动 Vivado
2. 点击 **Open Project**
3. 导航到：`D:\riscv\basic_rv32s\fpga\Vivado_Project\`
4. 选择：`RV32_Kintex7_SoC.xpr`
5. 点击 **OK**

---

## 📋 工程信息

### 工程结构
```
D:\riscv\basic_rv32s\fpga\Vivado_Project\
├── RV32_Kintex7_SoC.xpr          # 工程文件（双击打开）
├── RV32_Kintex7_SoC.cache\       # 缓存文件
├── RV32_Kintex7_SoC.hw\          # 硬件输出
├── RV32_Kintex7_SoC.runs\        # 运行结果
│   ├── synth_1\                  # 综合结果
│   └── impl_1\                   # 实现结果
├── RV32_Kintex7_SoC.sim\         # 仿真文件
└── mmu_test.hex                  # 测试程序
```

### 工程包含的模块
- ✅ RV32I 5级流水线 CPU（已包含 JALR 修复）
- ✅ AXI 总线互连
- ✅ 内存控制器
- ✅ UART 串口
- ✅ GPIO（LED 控制）
- ✅ 中断控制器（CLINT）
- ✅ MMU（内存管理单元）

---

## 🔧 JALR 修复验证流程

### 1. 打开工程
```
双击：D:\riscv\basic_rv32s\fpga\Vivado_Project\RV32_Kintex7_SoC.xpr
```

### 2. 检查源文件
打开工程后，在 **Sources** 窗口中确认：
- ✅ `RV32I46F_5SP_MMIO.v` - 包含 JALR 前递逻辑
- ✅ `Hazard_Unit.v` - 包含 Load-Use 冒险检测

### 3. 运行综合
```
Flow Navigator → Run Synthesis (F11)
```

### 4. 检查综合结果
查看：
- ✅ 综合成功
- ✅ 无严重错误
- ✅ 资源使用合理

### 5. 运行实现
```
Flow Navigator → Run Implementation
```

### 6. 检查时序
```
Reports → Timing Summary
查看 WNS (应该 >= 0)
```

### 7. 生成比特流
```
Flow Navigator → Generate Bitstream
```

### 8. 下载到 FPGA
```
Flow Navigator → Open Hardware Manager → Program Device
```

### 9. 验证结果
打开串口终端（115200 波特率），观察 RT-Thread 启动输出。

---

## 📊 预期的综合结果

### 资源使用（参考值）
```
LUT:    ~15000 / 63400  (约 24%)
FF:     ~8000  / 126800 (约 6%)
BRAM:   ~50    / 135    (约 37%)
DSP:    ~3     / 240    (约 1%)
```

### 时序（参考值）
```
时钟频率: 50 MHz (20ns 周期)
WNS:      >= 0 ns (应该满足)
TNS:      0 ns
```

**注意**：实际值可能因板子型号和优化级别而异。

---

## ⚠️ 注意事项

### 1. 工程路径
- ✅ 工程在 `fpga/Vivado_Project/` 目录
- ✅ 源代码在 `basic_rv32s/modules/` 目录
- ⚠️ 工程会引用源代码目录，不要移动文件夹

### 2. 修改后的文件
JALR 修复修改了以下文件：
- `basic_rv32s/modules/RV32I46F_5SP_MMIO.v`
- `basic_rv32s/modules/Hazard_Unit.v`

这些文件会被 Vivado 工程自动引用，无需手动复制。

### 3. 重新综合
如果你修改了代码，需要：
1. 保存源文件
2. 在 Vivado 中点击 **Run Synthesis** 重新综合
3. 然后运行 Implementation 和 Generate Bitstream

### 4. 板子型号
确认你的板子型号与工程配置匹配：
- 工程配置：查看 **Settings → General → Part**
- 你的板子：MK160TFA（应该是 Kintex-7 或 Artix-7）

如果不匹配，需要在 **Settings** 中修改 Part。

---

## 🆘 常见问题

### Q1: 双击 .xpr 文件没反应？
**A**: 确认 Vivado 已安装并关联了 .xpr 文件类型。
- 右键 .xpr → 打开方式 → 选择 Vivado
- 或者从 Vivado 内部 Open Project

### Q2: 打开工程报错？
**A**: 可能是 Vivado 版本不匹配。
- 你的版本：2019.2
- 工程版本：应该也是 2019.2
- 如果不同，Vivado 会提示升级工程

### Q3: 找不到源文件？
**A**: 工程使用相对路径引用源文件。
- 不要移动 `basic_rv32s` 文件夹
- 不要移动 `fpga` 文件夹
- 保持原有的目录结构

### Q4: 综合/实现失败？
**A**: 查看错误信息：
- 语法错误 → 检查修改的代码
- 资源不足 → 可能板子太小
- 时序违例 → 降低时钟频率

---

## 📞 需要帮助？

如果遇到问题，提供以下信息：
1. Vivado 版本
2. FPGA 板子型号
3. 错误信息截图
4. 综合/实现日志

我会帮你解决！

---

## ✅ 快速检查清单

在打开工程前：
- [ ] 确认 Vivado 已安装（版本 2019.2）
- [ ] 确认工程路径：`D:\riscv\basic_rv32s\fpga\Vivado_Project\`
- [ ] 确认源代码在：`D:\riscv\basic_rv32s\modules\`
- [ ] 确认修改的文件存在且正确

打开工程后：
- [ ] 工程正常打开，无错误
- [ ] Sources 窗口显示所有源文件
- [ ] 能看到 RV32I46F_5SP_MMIO.v 和 Hazard_Unit.v

---

**工程位置**: `D:\riscv\basic_rv32s\fpga\Vivado_Project\RV32_Kintex7_SoC.xpr`

**双击打开，开始验证你的 JALR 修复吧！** 🚀
