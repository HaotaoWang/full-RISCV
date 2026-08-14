# basic_rv32s 项目验证路线图

最终目标：在统一、可重复的验证流程下通过 CPU/中断回归，运行 Dhrystone、CoreMark，并通过本 CPU 所实现扩展范围内的 RISC-V Architecture Tests。

## 阶段 1：CPU 基础回归（已完成）

- AXI 请求握手与防重放。
- `lw -> jalr`、函数调用和 `ret`。
- LB/LBU/LH/LHU/LW 与 SB/SH/SW，包含符号扩展和字节选通。
- 两层函数嵌套、RA/保存寄存器及栈帧建立恢复。
- load-use ALU、load→branch、load→store、store→branch、访存等待期间跳转和 load→RET。
- 非对齐 LH/LW/SH/SW，精确检查 `mepc/mcause/mtval/mstatus` 且错误 store 无副作用。
- MRET 防重复处理。
- 验收：`python regression/run_regression.py --quick` 全部通过；当前基线为 9/9。

## 阶段 2：中断与上下文切换（已完成）

- 定时器中断与 taken branch/JAL 冲突。
- 定时器中断打断普通 ALU、等待中的 load/store、JALR 和 RET。
- AXI 数据响应完成拍与等待中的 RET/IRQ 精确边界。
- 保存并恢复 30 个通用寄存器和 SP。
- 连续 500 次中断压力，每次检查 30 个通用寄存器和 SP。
- RT-Thread 首次启动和不重载 BRAM 的软复位二次启动。
- 验收：阶段 2 项目均进入完整回归并通过。

本阶段发现并修复了一个新问题：Trap Controller 在注册异常源短暂回到 NONE 时重新武装过早，jump 冲突下可能把同一次 IRQ 排队两次。现在需要连续两个空闲 NONE 采样才重新接收 trap。

## 阶段 3：RT-Thread 系统回归（已完成）

- 使用真实 RT-Thread 内核构建测试专用 `regression/firmware/rtthread_system.hex`。
- 验证主线程与 idle 线程均实际运行，并观察至少六次线程切换。
- 验证 `rt_thread_mdelay(2)` 连续完成、Tick 长时间递增且无提前唤醒。
- 在稳定执行窗口检查主线程和 idle 线程 SP 始终位于各自栈范围。
- 验证 `rt_interrupt_nest` 最大为 1，退出中断后最终回到 0。
- 在不重新加载 BRAM 的情况下连续完成两次软复位启动。
- 验收：快速回归 9/9、完整回归 12/12 全部通过。

## 阶段 4：Dhrystone（构建与仿真已完成，待上板跑分）

项目已有源码、构建规则和 `software/build/dhrystone/dhrystone.hex`。

1. 已建立独立构建脚本，固定 GCC 15.2.0、`rv32i_zicsr_zifencei/ilp32`、`-O2` 和正式 100000 次迭代。
2. 已建立 20 次短迭代仿真 testbench，自动检查最终变量、精确 PASS 标记、非零周期数、trap 与超时。
3. 已确认 FPGA CPU 实际为 50 MHz，并修正旧的 100 MHz 计分配置；正式输出包含 Dhrystones/s 和 DMIPS/MHz。
4. 已生成并保留正式 `software/build/dhrystone/dhrystone.hex`；当前完整回归基线为 13/13。
5. 待板子可用后连续运行三次，保存 UART 日志并填入正式成绩。

验收标准：连续三次运行结果一致，无异常、无死锁，并保存 ELF、HEX、串口日志和配置记录。

## 阶段 5：CoreMark（构建与仿真已完成，待上板跑分）

项目已有官方 CoreMark 源码、端口层及 `software/build/coremark/coremark.hex`，当前构建配置为 `-O2`、`PERFORMANCE_RUN=1`、`ITERATIONS=3000`。

1. 已确认 50 MHz CPU 时钟、机器级 `mcycle` 计时、STATIC 2K 数据区及约 30 KiB ELF 内存占用。
2. 已建立一次完整 iteration 的长冒烟测试，严格检查官方验证文本和 list/matrix/state CRC `e714/1fd7/8e3a`。
3. 已生成正式 3000 iterations 镜像；按一次迭代 1,253,650 cycles 估算约运行 75 秒，满足官方至少 10 秒要求。
4. 已输出整数定点 `CoreMark/MHz`，避免在无 FPU 的 RV32IM 上为报告引入软浮点开销。
5. 已修复 RV32M 乘法器声明被注释、DIV/REM 未实现，以及端口误读未实现 `cycle` CSR 导致 ticks 为 0 的问题。
6. 验收：快速回归 10/10、完整回归 15/15；正式三次上板成绩待板子可用后补录。

验收标准：官方校验通过，运行时间足够长，连续三次分数稳定，并保存可复现证据。

## 阶段 6：RISC-V Architecture Tests

保留的 `software/apps/riscv-arch-tests` 约 659 MB，是官方架构测试源及其依赖；wrapper 已支持生成单项或整套 HEX。

建议按实现范围递进，而不是直接一次运行全部测试：

1. 建立 signature/tohost 判定 testbench，先跑 1 个已知测试验证 PASS/FAIL 协议。
2. RV32I 基础指令：算术、逻辑、移位、分支、JAL/JALR、load/store。
3. Zicsr 与 Zifencei。
4. RV32M 乘除法。
5. 特权与 trap 相关项目，仅运行当前硬件明确实现的 M-mode 子集。
6. 生成逐项报告：测试名、扩展、PASS/FAIL、周期数、失败 signature 和首个异常 PC。

不支持的扩展必须标为 SKIP/UNSUPPORTED，不能计作 FAIL，也不能计作 PASS。最终报告需明确 ISA 字符串和已验证特权级范围。

## 阶段 7：最终上板验收

板子可用后依次执行：

1. 编程当前已知稳定 Bitstream，按复位键验证 RT-Thread 可重复启动。
2. 运行长时间 Tick/线程切换压力，至少 30 分钟无异常。
3. 分别烧录 Dhrystone、CoreMark，保存完整串口日志。
4. 抽取架构测试代表项上板复核仿真结论。
5. 固化最终 Bitstream、HEX、ELF、构建参数、时序报告和测试报告。

任何 RTL 修改都必须先通过快速回归；生成正式 Bitstream 前必须通过完整回归。
