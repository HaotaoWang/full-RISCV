    .global _start

    .section .init, "ax"
_start:
    /* Set up stack pointer */
    lui sp, 0x10        /* sp = 0x10000 */

    /* Initialize global pointer */
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    /* Clear BSS */
    la t0, __bss_start
    la t1, __bss_end
    beq t0, t1, 2f
1:
    sw zero, 0(t0)
    addi t0, t0, 4
    bltu t0, t1, 1b
2:

    /* Call main */
    call main

3:
    j 3b
