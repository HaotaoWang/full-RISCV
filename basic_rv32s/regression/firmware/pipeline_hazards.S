    .option norelax
    .section .init, "ax"
    .globl _start
_start:
    lui     sp, 0x0f
    li      t0, 0x3000
    li      t1, 0x12345678
    sw      t1, 0(t0)

    # Store-data forwarding and immediate load-use ALU dependency.
    li      t2, 0x2468ace0
    sw      t2, 4(t0)
    lw      t3, 4(t0)
    addi    t4, t3, 1
    li      t5, 0x2468ace1
    bne     t4, t5, fail_1

    # Load followed immediately by a branch using the loaded register.
    li      t5, 0x12345678
    lw      t4, 0(t0)
    beq     t4, t5, load_branch_ok
    jal     zero, fail_2
load_branch_ok:

    # Load result immediately becomes store data.
    lw      t4, 0(t0)
    sw      t4, 8(t0)
    lw      t5, 8(t0)
    bne     t4, t5, fail_3

    # An older store must complete before a taken branch redirects fetch.
    li      t2, 0x0badcafe
    sw      t2, 12(t0)
    beq     zero, zero, store_branch_ok
    jal     zero, fail_4
store_branch_ok:
    lw      t3, 12(t0)
    bne     t2, t3, fail_5

    # The load is waiting in MEM while JAL enters the pipeline.
    lw      a0, 0(t0)
    jal     ra, load_then_jump
    jal     zero, fail_6
load_then_jump:
    li      a1, 0x12345678
    bne     a0, a1, fail_7

    call    return_overlap
after_return:
    li      a1, 0x55aa55aa
    bne     a0, a1, fail_8

pass:
    li      t0, 0x3100
    li      t1, 0x600d600d
    sw      t1, 0(t0)
1:  jal     zero, 1b

return_overlap:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    li      a0, 0x55aa55aa
    addi    sp, sp, 16
    lw      ra, -4(sp)
    ret

fail_1: li t2, 1; jal zero, fail
fail_2: li t2, 2; jal zero, fail
fail_3: li t2, 3; jal zero, fail
fail_4: li t2, 4; jal zero, fail
fail_5: li t2, 5; jal zero, fail
fail_6: li t2, 6; jal zero, fail
fail_7: li t2, 7; jal zero, fail
fail_8: li t2, 8
fail:
    li      t0, 0x3100
    sw      t2, 0(t0)
2:  jal     zero, 2b
