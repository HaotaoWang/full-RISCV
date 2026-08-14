    .option norelax
    .section .init, "ax"
    .globl _start
_start:
    lui     sp, 0x0f
    la      t0, trap_entry
    csrw    mtvec, t0
    li      t0, 0x80
    csrw    mie, t0
    li      t0, 0x8
    csrs    mstatus, t0

    li      t0, 0x3000
    sw      zero, 0(t0)
    li      t1, 1
    sw      t1, 4(t0)

    li      x1,  0x101
    li      x3,  0x103
    li      x4,  0x104
    li      x5,  0x105
    li      x6,  0x106
    li      x7,  0x107
    li      x8,  0x108
    li      x9,  0x109
    li      x10, 0x10a
    li      x11, 0x10b
    li      x12, 0x10c
    li      x13, 0x10d
    li      x14, 0x10e
    li      x15, 0x10f
    li      x16, 0x110
    li      x17, 0x111
    li      x18, 0x112
    li      x19, 0x113
    li      x20, 0x114
    li      x21, 0x115
    li      x22, 0x116
    li      x23, 0x117
    li      x24, 0x118
    li      x25, 0x119
    li      x26, 0x11a
    li      x27, 0x11b
    li      x28, 0x11c
    li      x29, 0x11d
    li      x30, 0x11e
    li      x31, 0x11f

stable_loop:
    jal     zero, stable_loop

    .align 2
trap_entry:
    addi    sp, sp, -128
    sw      x1,    0(sp)
    sw      x3,    4(sp)
    sw      x4,    8(sp)
    sw      x5,   12(sp)
    sw      x6,   16(sp)
    sw      x7,   20(sp)
    sw      x8,   24(sp)
    sw      x9,   28(sp)
    sw      x10,  32(sp)
    sw      x11,  36(sp)
    sw      x12,  40(sp)
    sw      x13,  44(sp)
    sw      x14,  48(sp)
    sw      x15,  52(sp)
    sw      x16,  56(sp)
    sw      x17,  60(sp)
    sw      x18,  64(sp)
    sw      x19,  68(sp)
    sw      x20,  72(sp)
    sw      x21,  76(sp)
    sw      x22,  80(sp)
    sw      x23,  84(sp)
    sw      x24,  88(sp)
    sw      x25,  92(sp)
    sw      x26,  96(sp)
    sw      x27, 100(sp)
    sw      x28, 104(sp)
    sw      x29, 108(sp)
    sw      x30, 112(sp)
    sw      x31, 116(sp)

    li      x1,  -1
    li      x3,  -1
    li      x5,  -1
    li      x10, -1
    li      x18, -1
    li      x31, -1
    li      t0, 0x3000
    lw      t1, 0(t0)
    addi    t1, t1, 1
    sw      t1, 0(t0)

    lw      x1,    0(sp)
    lw      x3,    4(sp)
    lw      x4,    8(sp)
    lw      x5,   12(sp)
    lw      x6,   16(sp)
    lw      x7,   20(sp)
    lw      x8,   24(sp)
    lw      x9,   28(sp)
    lw      x10,  32(sp)
    lw      x11,  36(sp)
    lw      x12,  40(sp)
    lw      x13,  44(sp)
    lw      x14,  48(sp)
    lw      x15,  52(sp)
    lw      x16,  56(sp)
    lw      x17,  60(sp)
    lw      x18,  64(sp)
    lw      x19,  68(sp)
    lw      x20,  72(sp)
    lw      x21,  76(sp)
    lw      x22,  80(sp)
    lw      x23,  84(sp)
    lw      x24,  88(sp)
    lw      x25,  92(sp)
    lw      x26,  96(sp)
    lw      x27, 100(sp)
    lw      x28, 104(sp)
    lw      x29, 108(sp)
    lw      x30, 112(sp)
    lw      x31, 116(sp)
    addi    sp, sp, 128
    mret
