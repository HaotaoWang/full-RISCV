# basic_rv32s Dhrystone 验证说明

## 固定配置

- Dhrystone 版本：2.1
- 编译器：xPack GNU RISC-V Embedded GCC 15.2.0
- ISA/ABI：`rv32i_zicsr_zifencei` / `ilp32`
- 优化：`-O2`
- FPGA CPU 时钟：50 MHz
- 正式迭代次数：100000
- RAM：64 KiB；当前 ELF 占用约 30 KiB（text + data + bss）
- 计时源：`mcycle`

FPGA 顶层使用 100 MHz 板载时钟，经 MMCM 输出 50 MHz CPU 时钟。因此正式镜像必须按 50 MHz 计算 Dhrystones/s；不能沿用旧源码中的 100 MHz，否则结果会虚高一倍。

## 构建正式镜像

在项目根目录运行：

```powershell
python .\software\apps\dhrystone\build_dhrystone.py
```

输出文件：

- `software/build/dhrystone/dhrystone.elf`
- `software/build/dhrystone/dhrystone.hex`

需要改变正式迭代次数时：

```powershell
python .\software\apps\dhrystone\build_dhrystone.py --runs 200000 --cpu-hz 50000000
```

## 自动仿真冒烟测试

```powershell
python .\regression\run_regression.py dhrystone_smoke
```

冒烟固件固定运行 20 次，使用仿真 testbench 的 100 MHz 时钟。它会检查：

- Dhrystone 最终变量全部符合标准期望值；
- UART 出现精确的 `DHRYSTONE PASS runs=20 cycles=`；
- 周期数非零；
- UART 未出现 `DHRYSTONE FAIL` 或 `[TRAP]`；
- 程序在限定周期内结束。

冒烟测试只用于功能回归，输出的性能数字不是正式成绩。

## 上板验收（板子可用后）

1. 用正式 `dhrystone.hex` 生成或更新 Bitstream。
2. 串口使用 115200、8N1、无流控。
3. 连续运行三次，每次保存完整 UART 日志。
4. 每次必须出现 `DHRYSTONE PASS runs=100000 cycles=...`，且不能出现 `[TRAP]` 或 `DHRYSTONE FAIL`。
5. 记录 `Dhrystones per Second` 和 `DMIPS/MHz`；三次结果应一致或仅有可解释的极小差异。
6. 正式成绩必须注明 50 MHz、GCC 15.2.0、`-O2`、100000 iterations。

当前第四阶段已完成构建与仿真部分；正式三次上板性能数据待板子可用后补录。
