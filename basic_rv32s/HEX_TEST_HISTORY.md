# HEX 测试过程记录

更新日期：2026-08-13

本文件记录项目中保留的 HEX 镜像及其用途。HEX 是测试过程证据，因此项目清理时不删除。

## 已确认的关键测试过程

1. `bare_metal.hex`：最初的裸机 C 验证。上板串口成功打印 `Hello from bare-metal C!`，LED 正常闪烁，证明 FPGA 板、时钟、UART 与基础取指路径可用。
2. `test_jalr_simple.hex`、`test_jalr_hazard.hex`、`test_jalr_simple_word.hex`：JALR、返回地址与流水线冒险定位阶段使用的固件。
3. `timer_test.hex`：定时器/中断基础验证固件。
4. `rtthread.hex`：当前 RT-Thread 主镜像。已验证首次 Program Device 后持续输出 Tick，并验证板上复位后能够重新启动和继续运行。
5. `regression/firmware/jalr_load.hex`：自动回归固件，专门覆盖曾导致 RT-Thread 函数返回异常的 `lw -> jalr` 和 `ret` 路径；2026-08-13 自动仿真通过。
6. `regression/firmware/irq_redirect.hex`：定时器中断与 taken branch/JAL 同拍冲突测试；验证先完成较老的控制流重定向，再进入中断。
7. `regression/firmware/context_restore.hex`：上下文保存恢复及连续中断压力测试；当前完整回归执行 500 次中断，寄存器和 SP 全部保持正确。
8. `regression/firmware/basic_memory_stack.hex`：基础访存宽度、符号扩展、嵌套函数调用和栈帧恢复测试。
9. `regression/firmware/pipeline_hazards.hex`：load/store 与 ALU、branch、JAL、RET 的组合冒险测试。
10. `regression/firmware/misaligned_csr.hex`：非对齐 LH/LW/SH/SW 及 `mepc/mcause/mtval/mstatus` 精确性测试。
11. `regression/firmware/irq_boundaries.hex`：IRQ 打断 ALU、等待中的 load/store、JALR、RET 及 AXI 完成拍边界测试。
12. `regression/firmware/rtthread_system.hex`：第三阶段 RT-Thread 系统回归固件；验证 main/idle 调度、`rt_thread_mdelay`、Tick、线程栈范围、中断嵌套归零和两次软复位。该镜像使用测试专用 10 MHz 时钟定义加速仿真，不替代生产 `rtthread.hex`。
13. `regression/firmware/dhrystone_smoke.hex`：Dhrystone 2.1 的 20 次短迭代仿真镜像；自动检查标准最终变量、UART PASS 标记、非零周期、trap 和超时。仅用于功能回归。
14. `software/build/dhrystone/dhrystone.hex`：正式 Dhrystone 镜像；GCC 15.2.0、`rv32i_zicsr_zifencei/ilp32`、`-O2`、100000 iterations、50 MHz，待板子可用后连续三次采集正式成绩。
15. `regression/firmware/coremark_smoke.hex`：CoreMark 1.0 单次完整 iteration 仿真镜像；官方 2K performance CRC 为 list=`e714`、matrix=`1fd7`、state=`8e3a`，并验证非零 `mcycle`、UART 和无 trap。
16. `software/build/coremark/coremark.hex`：正式 CoreMark 镜像；GCC 15.2.0、`rv32im_zicsr_zifencei/ilp32`、`-O2`、STATIC 2K、3000 iterations、50 MHz，待板子可用后连续三次采集正式成绩。

## 当前 HEX 文件清单

### 项目根目录

- `bare_metal.hex`
- `led_test_axi.hex`
- `mmu_test.hex`
- `program.hex`
- `program_with_lw.hex`
- `rtthread.hex`
- `simple_led_test.hex`
- `simple_test.hex`
- `smode_test.hex`
- `test_jalr_hazard.hex`
- `test_jalr_simple.hex`
- `test_jalr_simple_word.hex`
- `timer_test.hex`

### 软件与自动回归

- `bare_metal_test/program.hex`
- `regression/firmware/jalr_load.hex`
- `regression/firmware/irq_redirect.hex`
- `regression/firmware/context_restore.hex`
- `regression/firmware/basic_memory_stack.hex`
- `regression/firmware/pipeline_hazards.hex`
- `regression/firmware/misaligned_csr.hex`
- `regression/firmware/irq_boundaries.hex`
- `regression/firmware/rtthread_system.hex`
- `regression/firmware/dhrystone_smoke.hex`
- `regression/firmware/coremark_smoke.hex`
- `software/build/coremark/coremark.hex`
- `software/build/dhrystone/dhrystone.hex`
- `software/rt_thread_app/rtthread.hex`
- `software/rt_thread_app/test_minimal.hex`
- `software/rt_thread_app/test_noio.hex`
- `software/rt_thread_app/test_simple.hex`
- `software/rtthread.hex`

### FPGA 工程副本

- `fpga/My_Kintex7_RV32_SoC/led_test_axi.hex`
- `fpga/My_Kintex7_RV32_SoC/mmu_test.hex`
- `fpga/My_Kintex7_RV32_SoC/program.hex`
- `fpga/My_Kintex7_RV32_SoC/rtthread.hex`
- `fpga/My_Kintex7_RV32_SoC/simple_led_test.hex`
- `fpga/My_Kintex7_RV32_SoC/test_led.hex`
- `fpga/Vivado_Project/basic_rv32s/led_only_test.hex`
- `fpga/Vivado_Project/basic_rv32s/uart_led_simple_test.hex`
- `fpga/Vivado_Project/mmu_test.hex`
- `fpga/Vivado_Project/rtthread.hex`

## 2026-08-13 自动回归结果

- 快速回归：9/9 通过；包含完整 CPU、异常和中断边界定向测试。
- 快速回归：10/10 通过；新增 RV32M 全操作与边界语义单元测试。
- 完整回归：15/15 通过；包含中断压力、RT-Thread、Dhrystone 和 CoreMark 官方 CRC 冒烟测试。
- 本次全套仿真耗时约 380 秒；测试默认不产生 VCD，避免重新制造大型波形文件。
