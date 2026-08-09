# 如何运行完整的功能仿真

## 📋 目标

运行完整的 RT-Thread 仿真，验证 JALR 修复是否有效。

---

## 🚀 快速开始

### 方法 1: 使用 PowerShell 脚本（推荐 Windows）

**步骤**：
```powershell
# 1. 打开 PowerShell
# 2. 进入项目目录
cd D:\riscv\basic_rv32s

# 3. 运行脚本
.\run_complete_sim.ps1
```

**预期时间**: 5-10 分钟

**你会看到**：
- 编译进度
- 仿真实时监控
- JALR/JAL 执行统计
- 最终测试结果

---

### 方法 2: 使用 Bash 脚本

**步骤**：
```bash
# 1. 打开 Git Bash
# 2. 进入项目目录
cd /d/riscv/basic_rv32s

# 3. 添加执行权限
chmod +x run_complete_sim.sh

# 4. 运行脚本
./run_complete_sim.sh
```

---

### 方法 3: 手动运行（了解每一步）

#### 步骤 1: 编译仿真

```bash
cd D:\riscv\basic_rv32s

iverilog -g2012 -o sim.vvp \
  -I../verilog-axi/rtl \
  -Imodules/cache \
  testbenches/RV32_SoC_AXI_tb.v \
  RV32_SoC_AXI_Top.v \
  modules/RV32I46F_5SP_MMIO.v \
  modules/axi_clint.v \
  modules/axi_ram_init.v \
  modules/cache/*.v \
  ../verilog-axi/rtl/axi_interconnect.v \
  ../verilog-axi/rtl/arbiter.v \
  ../verilog-axi/rtl/priority_encoder.v \
  testbenches/BUFG.v
```

**检查编译**：
- 应该显示 "编译成功" 或者没有错误
- 生成 `sim.vvp` 文件

#### 步骤 2: 运行仿真

```bash
vvp sim.vvp | tee simulation.log
```

**或者在 PowerShell 中**：
```powershell
vvp sim.vvp | Tee-Object -FilePath simulation.log
```

#### 步骤 3: 监控进度

**在另一个终端窗口中**：
```bash
# 持续查看最新输出
tail -f simulation.log
```

**或者在 PowerShell 中**：
```powershell
Get-Content simulation.log -Wait -Tail 20
```

#### 步骤 4: 等待完成

仿真会运行约 5-10 分钟，然后自动结束。

#### 步骤 5: 查看结果

```bash
# 查看最后100行
tail -100 simulation.log

# 搜索关键信息
grep "JALR执行次数" simulation.log
grep "JAL执行次数" simulation.log
```

---

## 📊 预期输出

### ✅ 成功的标志

仿真结束时应该看到：
```
========================================
 RT-Thread 仿真结果
========================================
 执行统计:
   总指令数: ~50000
   JAL执行次数: 350
   JALR执行次数: 150        👈 重要！应该 > 0
   最终PC: 0x00000xxx
========================================

 ✅ JALR正常工作 - 函数调用/返回机制正常
```

**关键指标**：
- `JALR执行次数 > 0` ✅ → JALR 修复成功
- `JALR执行次数 = 0` ❌ → JALR 仍有问题

---

## 🔍 监控关键信息

### 在仿真运行时，注意查看：

1. **JALR 执行记录**：
   ```
   [xxxxx] WB_JALR: PC=0x00000xxx, returned_to=0x00000xxx
   ```
   这表示 JALR 指令成功执行了

2. **JAL 执行记录**：
   ```
   [xxxxx] WB_JAL: PC=0x00000xxx, target=0x00000xxx
   ```
   对比：JAL 应该能正常执行

3. **进度指示**：
   ```
   [xxxxx] Progress: 10000 instructions, PC=0x00000xxx
   ```
   每执行 10000 条指令会显示一次

4. **RT-Thread 输出**（如果能启动）：
   ```
   \ | /
   - RT-Thread Operating System
   ```

---

## ⏱️ 时间估算

| 阶段 | 预计时间 |
|------|----------|
| 编译 | 30-60 秒 |
| 仿真 | 5-10 分钟 |
| 分析结果 | 即时 |
| **总计** | **6-12 分钟** |

**提示**：
- 如果超过 15 分钟，可能卡住了（按 Ctrl+C 停止）
- 可以在另一个终端监控进度

---

## 🛑 如何停止仿真

如果需要提前停止：

**方法 1: 优雅停止**
```
按 Ctrl+C
```

**方法 2: 强制停止（Windows）**
```powershell
# 查找进程
Get-Process vvp

# 停止进程
Stop-Process -Name vvp -Force
```

**方法 3: 强制停止（Linux/Bash）**
```bash
# 查找并停止
pkill vvp
```

---

## 📈 监控技巧

### 实时查看进度

**PowerShell**：
```powershell
# 在另一个窗口持续监控
Get-Content rt_thread_complete_sim.log -Wait -Tail 20
```

**Bash**：
```bash
# 持续显示最新20行
tail -f rt_thread_complete_sim.log
```

### 检查是否在运行

```bash
# 查看 vvp 进程
ps aux | grep vvp
```

### 查看日志文件大小

```bash
# 持续监控文件增长
watch -n 1 'ls -lh *.log'
```

**或 PowerShell**：
```powershell
while ($true) { 
    Get-ChildItem *.log | Select Name, Length
    Start-Sleep 2 
}
```

---

## 🔧 故障排查

### 问题 1: 编译失败

**错误信息**：
```
syntax error
Unknown module type
```

**解决**：
1. 检查所有源文件是否存在
2. 确认修改的代码语法正确
3. 查看 `compile.log` 了解详情

---

### 问题 2: 仿真卡住

**现象**：运行超过 15 分钟没有输出

**排查**：
```bash
# 查看日志最后几行
tail -20 rt_thread_complete_sim.log

# 查看进程状态
ps aux | grep vvp
```

**可能原因**：
1. PC 卡在某个位置（死循环）
2. 等待某个信号（握手失败）
3. 内存访问问题

**解决**：
- 停止仿真（Ctrl+C）
- 查看最后的 PC 值
- 使用波形文件调试

---

### 问题 3: JALR 执行次数 = 0

**现象**：仿真完成，但 `JALR执行次数: 0`

**可能原因**：
1. 程序在 JALR 之前就卡住了
2. JALR 修复仍有问题
3. 仿真时间太短

**排查**：
```bash
# 查看是否有 JAL 执行
grep "WB_JAL" simulation.log | head -5

# 查看最后的 PC
grep "最终PC" simulation.log

# 查看是否有 ID_JAL 信号
grep "ID_JAL" simulation.log | head -5
```

**如果有 JAL 但没有 JALR**：
- 说明程序运行了，但 JALR 有问题
- 需要查看波形文件调试

---

### 问题 4: 内存不足

**错误信息**：
```
Cannot allocate memory
```

**解决**：
1. 关闭其他程序
2. 减少仿真时间（修改 testbench）
3. 使用更强大的机器

---

## 📁 生成的文件

运行后会生成：

| 文件 | 说明 |
|------|------|
| `sim.vvp` | 编译后的仿真文件 |
| `compile.log` | 编译日志 |
| `rt_thread_complete_sim.log` | 仿真输出日志（重要）|
| `jalr_test_result.txt` | 提取的关键结果 |
| `dump.vcd` | 波形文件（如果启用）|

**查看关键文件**：
```bash
# 查看仿真日志
less rt_thread_complete_sim.log

# 搜索 JALR
grep -i jalr rt_thread_complete_sim.log

# 查看结果
cat jalr_test_result.txt
```

---

## 🎯 成功验证清单

仿真完成后，检查：

- [ ] 编译成功，无错误
- [ ] 仿真正常运行，未卡死
- [ ] JAL 执行次数 > 0
- [ ] **JALR 执行次数 > 0** ✨ 最重要！
- [ ] 看到 "JALR正常工作" 的消息
- [ ] 最终 PC 不是 0x00000000

**如果以上全部通过** → JALR 修复成功！ 🎉

---

## 🆘 需要帮助？

如果遇到问题：

1. **保存以下文件**：
   - `rt_thread_complete_sim.log`
   - `compile.log`
   - 最后显示的信息截图

2. **告诉我**：
   - 卡在哪个步骤
   - 错误信息是什么
   - JALR 执行次数是多少

3. **我会帮你**：
   - 分析日志
   - 定位问题
   - 提供解决方案

---

## 💡 提示

### 加速验证

如果只想快速验证 JALR 是否执行，可以：

1. 修改 `testbenches/RV32_SoC_AXI_tb.v` 第 147 行：
   ```verilog
   // 从
   #50000;
   // 改为
   #10000;  // 更短的仿真时间
   ```

2. 重新编译和运行

### 查看波形

如果需要详细调试：

1. 在 testbench 中启用波形输出（已默认启用）
2. 运行仿真后用 GTKWave 查看：
   ```bash
   gtkwave dump.vcd
   ```

3. 查看关键信号：
   - `jalr_forwarded_rs1`
   - `jalr_load_use_hazard`
   - `ID_jump`
   - `opcode`

---

## 🎉 预期结果

**如果修复成功**，你应该看到：
```
========================================
 RT-Thread 仿真结果
========================================
 执行统计:
   总指令数: ~45000
   JAL执行次数: 342
   JALR执行次数: 156  ✅ 成功！
   最终PC: 0x00000134
========================================

 ✅ JALR正常工作 - 函数调用/返回机制正常
```

**这证明**：
- ✅ JALR 指令能正常执行
- ✅ 函数调用/返回机制正常
- ✅ 修复有效

---

**准备好了吗？运行脚本开始验证吧！** 🚀

```powershell
.\run_complete_sim.ps1
```
