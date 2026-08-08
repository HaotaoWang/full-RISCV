    .global _start
    .global trap_entry

    .section .init, "ax"
_start:
    /* Set up stack pointer */
    la sp, _sp

    /* Initialize global pointer */
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    /* Setup mtvec to trap_entry */
    la t0, trap_entry
    csrw mtvec, t0

    /* Clear BSS */
    la t0, __bss_start
    la t1, __bss_end
    beq t0, t1, 2f
1:
    sw zero, 0(t0)
    addi t0, t0, 4
    bltu t0, t1, 1b
2:

    /* Call RT-Thread entry */
    call entry
    
3:
    j 3b

    .section .text, "ax"
    .align 2
trap_entry:
    /* Save registers */
    addi sp, sp, -32 * 4

    sw x1,  1 * 4(sp)
    /* Skip x2 (sp), saved later */
    sw x3,  3 * 4(sp)
    sw x4,  4 * 4(sp)
    sw x5,  5 * 4(sp)
    sw x6,  6 * 4(sp)
    sw x7,  7 * 4(sp)
    sw x8,  8 * 4(sp)
    sw x9,  9 * 4(sp)
    sw x10, 10 * 4(sp)
    sw x11, 11 * 4(sp)
    sw x12, 12 * 4(sp)
    sw x13, 13 * 4(sp)
    sw x14, 14 * 4(sp)
    sw x15, 15 * 4(sp)
    sw x16, 16 * 4(sp)
    sw x17, 17 * 4(sp)
    sw x18, 18 * 4(sp)
    sw x19, 19 * 4(sp)
    sw x20, 20 * 4(sp)
    sw x21, 21 * 4(sp)
    sw x22, 22 * 4(sp)
    sw x23, 23 * 4(sp)
    sw x24, 24 * 4(sp)
    sw x25, 25 * 4(sp)
    sw x26, 26 * 4(sp)
    sw x27, 27 * 4(sp)
    sw x28, 28 * 4(sp)
    sw x29, 29 * 4(sp)
    sw x30, 30 * 4(sp)
    sw x31, 31 * 4(sp)

    /* Save mepc and mstatus */
    csrr t0, mepc
    sw t0, 0 * 4(sp)
    csrr t0, mstatus
    sw t0, 2 * 4(sp)

    /* Call C trap handler */
    csrr a0, mcause
    csrr a1, mepc
    mv a2, sp
    call system_trap_handler

    /* Check if context switch is needed */
    la s0, rt_thread_switch_interrupt_flag
    lw s1, 0(s0)
    beqz s1, no_switch

    /* Clear the flag */
    sw zero, 0(s0)

    /* Switch sp */
    la s0, rt_interrupt_from_thread
    lw a0, 0(s0)
    sw sp, 0(a0)

    la s0, rt_interrupt_to_thread
    lw a1, 0(s0)
    lw sp, 0(a1)

no_switch:
    /* Jump to RT-Thread's exit routine (defined in context_gcc.S) */
    j rt_hw_context_switch_exit
