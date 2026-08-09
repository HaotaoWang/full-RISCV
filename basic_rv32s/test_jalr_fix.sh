#!/bin/bash
# JALR 修复验证脚本

set -e

echo "=========================================="
echo "JALR 数据冒险修复验证"
echo "=========================================="
echo ""

# 1. 编译测试程序
echo "[1/4] 编译 JALR 测试程序..."
riscv32-unknown-elf-as -march=rv32i -o test_jalr_hazard.o test_jalr_hazard.S
riscv32-unknown-elf-ld -Ttext=0x0 -o test_jalr_hazard.elf test_jalr_hazard.o
riscv32-unknown-elf-objcopy -O binary test_jalr_hazard.elf test_jalr_hazard.bin
riscv32-unknown-elf-objdump -d test_jalr_hazard.elf > test_jalr_hazard.dump

echo "   ✓ 编译完成"
echo ""

# 2. 显示反汇编
echo "[2/4] 反汇编代码（前20行）："
head -n 20 test_jalr_hazard.dump
echo "   ... (更多内容见 test_jalr_hazard.dump)"
echo ""

# 3. 提示检查点
echo "[3/4] 关键检查点："
echo "   - jalr_forwarded_rs1：JALR 前递逻辑是否生效"
echo "   - jalr_load_use_hazard：Load-Use 冒险是否被检测"
echo "   - IF_ID_stall：是否正确插入 stall"
echo "   - t0 寄存器值："
echo "       0xAAAA0001 -> 进入 test_jal_jalr"
echo "       0xAAAA0002 -> 从 func1 返回（JAL+JALR 成功）"
echo "       0xBBBB0002 -> ADDI+JALR 成功"
echo "       0xCCCC0002 -> Load+JALR 成功"
echo "       0xDDDD0005 -> 连续 JALR 成功"
echo "       0xFFFF0000 -> 全部测试通过！"
echo ""

# 4. 运行说明
echo "[4/4] 运行仿真："
echo "   方式1（快速测试）："
echo "     iverilog -g2012 -o sim testbenches/RV32_SoC_AXI_tb.v"
echo "     vvp sim"
echo ""
echo "   方式2（查看波形）："
echo "     iverilog -g2012 -o sim testbenches/RV32_SoC_AXI_tb.v"
echo "     vvp sim"
echo "     gtkwave dump.vcd"
echo ""

echo "=========================================="
echo "编译完成！请运行仿真验证修复效果"
echo "=========================================="
