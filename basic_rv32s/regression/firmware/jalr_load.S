    .section .init, "ax"
    .globl _start
_start:
    lui     sp, 0x10
    la      t1, target_pointer
    lw      t0, 0(t1)
    jalr    ra, 0(t0)
    addi    s0, zero, 1
finish:
    jal     zero, finish

target:
    addi    s1, zero, 2
    ret

    .section .rodata
    .align 2
target_pointer:
    .word target
