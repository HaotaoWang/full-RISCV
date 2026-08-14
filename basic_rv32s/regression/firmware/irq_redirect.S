    .option norelax
    .section .init, "ax"
    .globl _start
_start:
    lui     sp, 0x10
    la      t0, trap_entry
    csrw    mtvec, t0
    li      t0, 0x80
    csrw    mie, t0
    li      t0, 0x8
    csrs    mstatus, t0

    li      s0, 0
    li      s1, 0
    li      s2, 0
    li      s3, 0
    li      t0, 0x3000
    sw      zero, 0(t0)
    li      t1, 1
    sw      t1, 4(t0)

loop:
    addi    s0, s0, 1
    beq     zero, zero, branch_target
    addi    s1, s1, 1

branch_target:
    jal     ra, jump_target
    addi    s2, s2, 1
    jal     zero, loop

jump_target:
    addi    s3, s3, 1
    ret

    .align 2
trap_entry:
    addi    sp, sp, -16
    sw      t0, 0(sp)
    sw      t1, 4(sp)
    li      t0, 0x3000
    lw      t1, 0(t0)
    addi    t1, t1, 1
    sw      t1, 0(t0)
    lw      t0, 0(sp)
    lw      t1, 4(sp)
    addi    sp, sp, 16
    mret
