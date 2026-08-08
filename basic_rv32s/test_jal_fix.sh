#!/bin/bash
# 测试 JAL/JALR 修复

echo "=== 编译测试程序 ==="
riscv-none-elf-gcc -march=rv32im -mabi=ilp32 -nostdlib -T software/runtime/link.lds \
    test_jal_fix.c -o test_jal_fix.elf

if [ $? -ne 0 ]; then
    echo "编译失败！"
    exit 1
fi

echo "=== 生成 hex 文件 ==="
riscv-none-elf-objcopy -O binary test_jal_fix.elf test_jal_fix.bin
python software/runtime/makehex.py test_jal_fix.bin test_jal_fix.hex

echo "=== 反汇编查看生成的代码 ==="
riscv-none-elf-objdump -d test_jal_fix.elf | head -50

echo "=== 测试程序已准备好 ==="
echo "使用 test_jal_fix.hex 进行仿真测试"
