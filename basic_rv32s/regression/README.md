# basic_rv32s 回归测试

该目录把本次 RT-Thread 移植过程中出现过的关键 CPU 问题固化为可重复测试。

## 使用方法

在项目根目录运行：

```powershell
python .\regression\run_regression.py --quick
```

快速测试通常用于每次修改 RTL 后，覆盖：

- `axi_adapter`：AXI 读写请求只完成一次，CPU 保持 `mem_valid` 时不会重放。
- `trap_rearm`：持续一个以上周期的 MRET 只处理一次，信号回到 NONE 后可再次触发。
- `jalr_load`：覆盖曾导致 RT-Thread 函数返回失败的 `lw -> jalr` 以及 `ret` 路径。
- `basic_memory_stack`：覆盖 LB/LBU/LH/LHU/LW、SB/SH/SW、符号扩展、两层嵌套调用及栈帧恢复。
- `pipeline_hazards`：覆盖 load-use ALU、load→branch、load→store、store→branch、访存等待期间 JAL，以及 load→RET。
- `misaligned_csr`：覆盖非对齐 LH/LW/SH/SW，并精确检查 `mepc/mcause/mtval/mstatus`、SP、保存寄存器和错误 store 无副作用。
- `irq_redirect`：分别让定时器中断撞上 taken branch 和 JAL，检查中断不会越过更老的控制流重定向，也不会重复进入。
- `irq_boundaries`：分别让定时器中断打断 ALU、等待中的 load/store、JALR、RET，以及 AXI 完成拍释放等待中 RET 的精确边界；逐项检查 `mepc/mcause/mstatus`、上下文和访存结果。
- `context_restore`：中断处理程序保存、破坏并恢复除 `x0/sp` 外的 30 个通用寄存器，同时检查 SP 和 MRET 返回。

在生成 Bitstream 前运行完整测试：

```powershell
python .\regression\run_regression.py --full
```

完整测试额外使用当前 `rtthread.hex` 启动 RT-Thread，运行一段时间后模拟板上复位键；第二次启动不会重新加载 BRAM，以验证启动代码的 `.data` 恢复逻辑。

完整测试还包含 `irq_stress`：连续注入 500 次定时器中断，每次返回后都检查 30 个通用寄存器、SP 和中断计数。

`rtthread_scheduler` 会构建测试专用 `rtthread_system.hex`，并连续完成两次软复位。每次启动均检查主线程/idle 线程运行、至少三轮 `rt_thread_mdelay(2)`、Tick 持续递增、至少六次线程切换、稳定执行窗口内的 SP 栈范围，以及 `rt_interrupt_nest` 最大为 1 并最终归零。该固件只在回归构建中把系统时钟定义为 10 MHz 以缩短仿真，生产 `rtthread.hex` 仍使用 50 MHz 配置。

`dhrystone_smoke` 构建并运行 20 次迭代的 Dhrystone 2.1，自动检查最终变量、UART PASS 标记、非零周期数、trap 和超时。该测试用于功能回归，不作为正式性能成绩。

`coremark_smoke` 运行一次完整 CoreMark 1.0 iteration，检查官方验证文本、2K performance 的 list/matrix/state CRC（`e714/1fd7/8e3a`）、非零 `mcycle`、UART PASS/FAIL、trap 和超时。该长测试约需 2.5 分钟。

还可以列出测试或只运行指定测试：

```powershell
python .\regression\run_regression.py --list
python .\regression\run_regression.py jalr_load
python .\regression\run_regression.py irq_redirect context_restore
python .\regression\run_regression.py irq_stress
python .\regression\run_regression.py rtthread_scheduler
python .\regression\run_regression.py dhrystone_smoke
python .\regression\run_regression.py coremark_smoke
```

当前基线（2026-08-13）：快速回归 10/10 通过，完整回归 15/15 通过。

## 文件保留规则

- 测试固件源码与生成的 `regression/firmware/*.hex` 保留，作为项目测试过程记录。
- `.elf`、`.bin`、`.vvp` 放在 `regression/out/`，属于可重建临时文件，不纳入版本管理。
- 测试默认不生成 VCD；定位失败时再针对单项加入波形，避免产生大型临时文件。
