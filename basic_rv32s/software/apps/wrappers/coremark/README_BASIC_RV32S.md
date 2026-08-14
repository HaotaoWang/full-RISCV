# basic_rv32s CoreMark 验证说明

## 正式配置

- CoreMark：1.0，2K performance seeds
- 编译器：xPack GNU RISC-V Embedded GCC 15.2.0
- ISA/ABI：`rv32im_zicsr_zifencei` / `ilp32`
- 优化：`-O2`
- CPU 时钟：50 MHz
- 正式迭代次数：3000
- 内存方法：STATIC，2K 数据区，单上下文
- 计时源：机器级 `mcycle` 低 32 位

一次仿真迭代测得 1,253,650 CPU cycles。由此估算 3000 次在 50 MHz 下约运行 75 秒，满足 CoreMark 至少 10 秒的正式报告要求，同时低于 32 位 `mcycle` 在 50 MHz 下约 85.9 秒的回绕周期。

## 构建正式镜像

在项目根目录运行：

```powershell
python .\software\apps\wrappers\coremark\build_coremark.py
```

输出：

- `software/build/coremark/coremark.elf`
- `software/build/coremark/coremark.hex`

可选参数：

```powershell
python .\software\apps\wrappers\coremark\build_coremark.py --iterations 3000 --cpu-hz 50000000
```

## 仿真冒烟测试

```powershell
python .\regression\run_regression.py coremark_smoke
```

测试运行一次完整 CoreMark iteration，并严格检查：

- 官方文本 `Correct operation validated.`；
- list CRC：`0xe714`；
- matrix CRC：`0x1fd7`；
- state CRC：`0x8e3a`；
- `COREMARK PASS iterations=1 ticks=` 后周期数非零；
- 不出现 `COREMARK FAIL`、`[TRAP]` 或超时。

冒烟构建仅豁免官方“至少运行 10 秒”限制，不改变算法、performance seeds、数据规模或 CRC。它不是正式性能成绩。

## 上板验收

1. 使用正式 `coremark.hex` 生成 Bitstream，串口设为 115200、8N1、无流控。
2. 连续运行三次并保存完整 UART 日志。
3. 每次必须出现标准三项 CRC、`Correct operation validated.` 和 `COREMARK PASS iterations=3000`。
4. 不得出现 `Errors detected`、`COREMARK FAIL` 或 `[TRAP]`。
5. 确认 `Total time (secs)` 不少于 10 秒。
6. 记录 `CoreMark/MHz`，并注明 GCC 15.2.0、`-O2`、RV32IM、50 MHz、STATIC 2K、3000 iterations。

当前第五阶段的构建与仿真验证已完成；三次正式上板成绩待板子可用后补录。
