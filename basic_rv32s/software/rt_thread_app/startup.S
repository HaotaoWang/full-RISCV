    .global _start
    .global trap_entry

    .section .init, "ax"
_start:
    /* Set up stack pointer - use explicit address to avoid la pseudo-instruction issues */
    lui sp, 0x10        /* Load upper immediate: sp = 0x10000 */

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

    /* Enable global interrupts (mstatus.MIE) */
    li t0, 0x8
    csrs mstatus, t0

    /* Call RT-Thread entry */
    call entry

3:
    j 3b

    .section .text, "ax"
    .align 2
trap_entry:
    /* Save context - MUST match rt_hw_stack_frame structure in cpuport.c
     * Stack layout after save (from low to high address):
     *   sp[0]  = epc
     *   sp[1]  = ra (x1)
     *   sp[2]  = mstatus (with MIE/MPIE info)
     *   sp[3]  = gp (x3)
     *   sp[4]  = tp (x4)
     *   ...
     *   sp[31] = t6 (x31)
     */
    addi sp, sp, -32 * 4

    /* Save epc at sp[0] */
    csrr t0, mepc
    sw t0, 0 * 4(sp)

    /* Save ra at sp[1] */
    sw x1, 1 * 4(sp)

    /* Save mstatus at sp[2] - extract MIE bit and convert to MPIE format
     * RT-Thread expects: if MIE was set, store 0x80 (MPIE=1), else 0x00
     */
    csrr t0, mstatus
    andi t0, t0, 0x8         /* Extract MIE bit (bit 3) */
    beqz t0, 1f
    li t0, 0x80              /* If MIE=1, set MPIE=1 (bit 7) */
1:
    sw t0, 2 * 4(sp)

    /* Save gp-t6 (x3-x31), skip x2(sp) as it's managed by RT-Thread */
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

    /* Save current thread sp */
    la s0, rt_interrupt_from_thread
    lw a0, 0(s0)
    sw sp, 0(a0)

    /* Load new thread sp */
    la s0, rt_interrupt_to_thread
    lw a1, 0(s0)
    lw sp, 0(a1)

no_switch:
    /* Jump to RT-Thread's exit routine */
    j rt_hw_context_switch_exit
