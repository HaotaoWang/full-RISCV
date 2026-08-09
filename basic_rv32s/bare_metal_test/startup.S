    .section .text
    .global _start
_start:
    /* Set stack pointer to end of 64KB RAM */
    lui sp, 0x10
    
    /* Call main */
    call main

    /* Infinite loop if main returns */
1:  j 1b
