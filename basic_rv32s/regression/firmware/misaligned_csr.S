    .option norelax
    .section .init, "ax"
    .globl _start
_start:
    lui     sp, 0x0f
    la      t0, trap_entry
    csrw    mtvec, t0
    li      t0, 8
    csrs    mstatus, t0

    li      s0, 0x135
    li      s1, 0x246
    li      t0, 0x3000
    li      t1, 0x11223344
    sw      t1, 0(t0)
    li      t1, 0x55667788
    sw      t1, 4(t0)
    li      t0, 0x3200
    sw      zero, 0(t0)

    li      t0, 0x3300
    la      t1, misaligned_lh
    sw      t1, 0(t0)
    la      t1, misaligned_lw
    sw      t1, 4(t0)
    la      t1, misaligned_sh
    sw      t1, 8(t0)
    la      t1, misaligned_sw
    sw      t1, 12(t0)

    li      t0, 0x3000
misaligned_lh:
    lh      a0, 1(t0)
misaligned_lw:
    lw      a0, 1(t0)
    li      t2, 0xaabbccdd
misaligned_sh:
    sh      t2, 1(t0)
misaligned_sw:
    sw      t2, 2(t0)

    li      t0, 0x3000
    lw      t1, 0(t0)
    li      t2, 0x11223344
    bne     t1, t2, fail_1
    lw      t1, 4(t0)
    li      t2, 0x55667788
    bne     t1, t2, fail_2
    li      t0, 0x3200
    lw      t1, 0(t0)
    li      t2, 4
    bne     t1, t2, fail_3
    lui     t1, 0x0f
    bne     sp, t1, fail_4
    li      t1, 0x135
    bne     s0, t1, fail_5
    li      t1, 0x246
    bne     s1, t1, fail_6
    csrr    t1, mstatus
    sw      t1, 4(t0)

pass:
    li      t0, 0x3100
    li      t1, 0x600d600d
    sw      t1, 0(t0)
1:  jal     zero, 1b

    .align 2
trap_entry:
    addi    sp, sp, -48
    sw      t0, 0(sp)
    sw      t1, 4(sp)
    sw      t2, 8(sp)
    sw      t3, 12(sp)
    sw      t4, 16(sp)
    sw      t5, 20(sp)
    sw      t6, 24(sp)
    sw      a0, 28(sp)
    csrr    t0, mcause
    csrr    t1, mepc
    csrr    t2, mtval
    csrr    t3, mstatus
    li      t4, 0x3200
    lw      t5, 0(t4)
    slli    t6, t5, 4
    addi    t6, t6, 16
    add     t6, t6, t4
    sw      t0, 0(t6)
    sw      t1, 4(t6)
    sw      t2, 8(t6)
    sw      t3, 12(t6)
    addi    t5, t5, 1
    sw      t5, 0(t4)
    addi    t1, t1, 4
    csrw    mepc, t1
    lw      t0, 0(sp)
    lw      t1, 4(sp)
    lw      t2, 8(sp)
    lw      t3, 12(sp)
    lw      t4, 16(sp)
    lw      t5, 20(sp)
    lw      t6, 24(sp)
    lw      a0, 28(sp)
    addi    sp, sp, 48
    mret

fail_1: li t2, 1; jal zero, fail
fail_2: li t2, 2; jal zero, fail
fail_3: li t2, 3; jal zero, fail
fail_4: li t2, 4; jal zero, fail
fail_5: li t2, 5; jal zero, fail
fail_6: li t2, 6
fail:
    li      t0, 0x3100
    sw      t2, 0(t0)
2:  jal     zero, 2b
