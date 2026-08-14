    .option norelax
    .section .init, "ax"
    .globl _start
_start:
    lui     sp, 0x0f
    la      t0, trap_entry
    csrw    mtvec, t0
    li      t0, 0x80
    csrw    mie, t0
    li      t0, 8
    csrs    mstatus, t0

    li      s0, 0x180
    li      s1, 0x181
    li      s2, 0x182
    li      s3, 0x183
    li      s4, 0
    li      s5, 0
    li      s6, 0
    li      s7, 0

    li      t0, 0x3000
    sw      zero, 0(t0)
    li      t1, 1
    sw      t1, 4(t0)
    li      t0, 0x3010
    li      t1, 0x12345678
    sw      t1, 0(t0)

    # Export exact PCs so the testbench does not depend on hard-coded ELF
    # addresses. Each entry is a word at 0x3300.
    li      t0, 0x3300
    la      t1, alu_point
    sw      t1, 0(t0)
    la      t1, load_point
    sw      t1, 4(t0)
    la      t1, store_point
    sw      t1, 8(t0)
    la      t1, jalr_point
    sw      t1, 12(t0)
    la      t1, indirect_target
    sw      t1, 16(t0)
    la      t1, ret_point
    sw      t1, 20(t0)
    la      t1, after_ret
    sw      t1, 24(t0)
    la      t1, overlap_ret
    sw      t1, 28(t0)
    la      t1, after_overlap
    sw      t1, 32(t0)

main_loop:
alu_point:
    addi    s4, s4, 1
    li      t0, 0x3010
load_point:
    lw      t2, 0(t0)
store_point:
    sw      t2, 4(t0)

    la      t3, indirect_target
jalr_point:
    jalr    ra, 0(t3)
    addi    s5, s5, 1

    call    ret_function
after_ret:
    addi    s6, s6, 1

    call    overlap_function
after_overlap:
    addi    s7, s7, 1
    jal     zero, main_loop

indirect_target:
    ret

ret_function:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
ret_point:
    ret

overlap_function:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    addi    sp, sp, 16
    lw      ra, -4(sp)
overlap_ret:
    ret

    .align 2
trap_entry:
    addi    sp, sp, -48
    sw      ra, 0(sp)
    sw      t0, 4(sp)
    sw      t1, 8(sp)
    sw      t2, 12(sp)
    sw      t3, 16(sp)
    sw      t4, 20(sp)
    sw      t5, 24(sp)
    sw      t6, 28(sp)
    sw      a0, 32(sp)
    sw      a1, 36(sp)

    csrr    t0, mcause
    csrr    t1, mepc
    csrr    t2, mstatus
    li      t3, 0x3200
    lw      t4, 0(t3)
    addi    t4, t4, 1
    sw      t4, 0(t3)
    sw      t0, 4(t3)
    sw      t1, 8(t3)
    sw      t2, 12(t3)

    lw      ra, 0(sp)
    lw      t0, 4(sp)
    lw      t1, 8(sp)
    lw      t2, 12(sp)
    lw      t3, 16(sp)
    lw      t4, 20(sp)
    lw      t5, 24(sp)
    lw      t6, 28(sp)
    lw      a0, 32(sp)
    lw      a1, 36(sp)
    addi    sp, sp, 48
    mret
