    .option norelax
    .section .init, "ax"
    .globl _start
_start:
    lui     sp, 0x0f
    li      s0, 0x111
    li      s1, 0x222
    li      t0, 0x3000
    li      t1, 0x80ff7f01
    sw      t1, 0(t0)

    lb      a0, 0(t0)
    li      a1, 1
    bne     a0, a1, fail_1
    lb      a0, 1(t0)
    li      a1, 127
    bne     a0, a1, fail_2
    lb      a0, 2(t0)
    li      a1, -1
    bne     a0, a1, fail_3
    lb      a0, 3(t0)
    li      a1, -128
    bne     a0, a1, fail_4
    lbu     a0, 2(t0)
    li      a1, 255
    bne     a0, a1, fail_5
    lbu     a0, 3(t0)
    li      a1, 128
    bne     a0, a1, fail_6

    lh      a0, 0(t0)
    li      a1, 0x7f01
    bne     a0, a1, fail_7
    lh      a0, 2(t0)
    li      a1, -32513
    bne     a0, a1, fail_8
    lhu     a0, 2(t0)
    li      a1, 0x80ff
    bne     a0, a1, fail_9
    lw      a0, 0(t0)
    bne     a0, t1, fail_10

    li      t2, 0x11223344
    sw      t2, 4(t0)
    li      t3, 0xaa
    sb      t3, 5(t0)
    li      t3, 0x55cc
    sh      t3, 6(t0)
    lw      a0, 4(t0)
    li      a1, 0x55ccaa44
    bne     a0, a1, fail_11

    call    outer_frame
    li      a1, 21
    bne     a0, a1, fail_12
    li      a1, 0x111
    bne     s0, a1, fail_13
    li      a1, 0x222
    bne     s1, a1, fail_14
    lui     a1, 0x0f
    bne     sp, a1, fail_15

pass:
    li      t0, 0x3100
    li      t1, 0x600d600d
    sw      t1, 0(t0)
1:  jal     zero, 1b

outer_frame:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    li      s0, 5
    li      a0, 7
    call    inner_frame
    add     a0, a0, s0
    lw      s0, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

inner_frame:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s1, 8(sp)
    li      s1, 9
    add     a0, a0, s1
    lw      s1, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

fail_1:  li t2, 1;  jal zero, fail
fail_2:  li t2, 2;  jal zero, fail
fail_3:  li t2, 3;  jal zero, fail
fail_4:  li t2, 4;  jal zero, fail
fail_5:  li t2, 5;  jal zero, fail
fail_6:  li t2, 6;  jal zero, fail
fail_7:  li t2, 7;  jal zero, fail
fail_8:  li t2, 8;  jal zero, fail
fail_9:  li t2, 9;  jal zero, fail
fail_10: li t2, 10; jal zero, fail
fail_11: li t2, 11; jal zero, fail
fail_12: li t2, 12; jal zero, fail
fail_13: li t2, 13; jal zero, fail
fail_14: li t2, 14; jal zero, fail
fail_15: li t2, 15
fail:
    li      t0, 0x3100
    sw      t2, 0(t0)
2:  jal     zero, 2b
