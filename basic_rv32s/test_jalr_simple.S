# 简化版 JALR 测试 - 只测试最基本的 JAL+JALR
.section .text
.globl _start

_start:
    # 初始化
    li sp, 0x10000
    li t0, 0x1111

    # 测试 JAL + JALR 返回
    jal ra, func1
    li t0, 0x2222

    # 成功标记
    li t0, 0xFFFF
    j end_loop

func1:
    li t1, 0x3333
    jalr x0, ra, 0

end_loop:
    j end_loop
