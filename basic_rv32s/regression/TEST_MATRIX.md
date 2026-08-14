# 自动回归测试矩阵

更新日期：2026-08-13

| 测试 | 主要覆盖 | 当前结果 |
|---|---|---|
| `axi_adapter` | AXI 读写握手、VALID 保持、防请求重放 | PASS |
| `rv32m_unit` | MUL/MULH/MULHSU/MULHU、DIV/DIVU/REM/REMU、除零和溢出语义 | PASS |
| `trap_rearm` | MRET/trap 电平防重复、连续两个 NONE 后重新武装 | PASS |
| `jalr_load` | `lw -> jalr`、函数返回 | PASS |
| `basic_memory_stack` | LB/LBU/LH/LHU/LW、SB/SH/SW、符号扩展、嵌套栈帧 | PASS |
| `pipeline_hazards` | load-use、load→branch/store、store→branch、JAL、RET 与访存重叠 | PASS |
| `misaligned_csr` | 非对齐 LH/LW/SH/SW、mepc/mcause/mtval/mstatus、无错误写副作用 | PASS |
| `irq_redirect` | 定时器中断撞 taken branch/JAL | PASS |
| `irq_boundaries` | IRQ 打断 ALU、等待中的 load/store、JALR、RET、AXI 完成拍；CSR 与上下文精确性 | PASS |
| `context_restore` | 4 次中断、30 个通用寄存器和 SP 恢复 | PASS |
| `irq_stress` | 500 次连续中断与 MRET，每次检查 30 个寄存器和 SP | PASS |
| `rtthread_soft_reset` | RT-Thread 首次启动与不重载 BRAM 的复位二次启动 | PASS |
| `rtthread_scheduler` | 两次软复位、main/idle 切换、`mdelay`、Tick、线程栈范围、中断嵌套归零 | PASS |
| `dhrystone_smoke` | Dhrystone 2.1 短迭代、最终变量自检、mcycle、UART PASS/FAIL/trap/超时判定 | PASS |
| `coremark_smoke` | CoreMark 2K performance、官方验证文本、三项标准 CRC、非零 mcycle、UART/trap/超时 | PASS |

## 下一批建议

- 板子可用后连续运行三次正式 Dhrystone（100000 iterations、50 MHz），保存 UART 日志并记录 Dhrystones/s 与 DMIPS/MHz。
- 板子可用后连续运行三次正式 CoreMark（3000 iterations、50 MHz），保存 UART 日志和 CoreMark/MHz。
- 下一开发阶段进入 RISC-V Architecture Tests 的 signature/tohost 框架。
- 后续长跑阶段可把中断压力提升到 1000 次；当前日常完整回归固定为 500 次。
