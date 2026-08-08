#include <rthw.h>
#include <rtthread.h>
#include <stdint.h>

#define CLINT_MTIMECMP  (*((volatile uint32_t*)0x02004000))
#define CLINT_MTIME     (*((volatile uint32_t*)0x0200BFF8))
#define UART_TX_REG     (*((volatile uint32_t*)0x10010000))
#define UART_STATUS_REG (*((volatile uint32_t*)0x10010004))

#define SYSTEM_CLOCK    50000000
#define TICK_CYCLES     (SYSTEM_CLOCK / RT_TICK_PER_SECOND)

extern int _end;

void rt_hw_console_output(const char *str)
{
    while (*str) {
        if (*str == '\n') {
            while (UART_STATUS_REG & 0x01);
            UART_TX_REG = '\r';
        }
        while (UART_STATUS_REG & 0x01);
        UART_TX_REG = *str++;
    }
}

void rt_hw_board_init(void)
{
    /* Configure SysTick */
    CLINT_MTIMECMP = CLINT_MTIME + TICK_CYCLES;

    /* Enable Machine Timer Interrupt (MTIE) in mie register */
    __asm__ volatile(
        "li t0, 0x80\n\t"
        "csrs mie, t0"
    );

    /* Enable global interrupts (mstatus.MIE) */
    __asm__ volatile(
        "li t0, 0x8\n\t"
        "csrs mstatus, t0"
    );

    /* Initialize System Heap */
    rt_system_heap_init((void*)&_end, (void*)(0x00000000 + 64*1024 - 4096));
}

void system_trap_handler(rt_ubase_t mcause, rt_ubase_t mepc, rt_ubase_t sp)
{
    /* mcause bit 31 indicates interrupt */
    if (mcause & 0x80000000) {
        rt_ubase_t exception_code = mcause & 0x7FFFFFFF;
        if (exception_code == 7) { /* Machine Timer Interrupt */
            CLINT_MTIMECMP += TICK_CYCLES;
            rt_tick_increase();
        }
    } else {
        /* Exception (e.g., ecall, illegal instruction, etc.) */
        rt_kprintf("Exception! mcause: 0x%08x, mepc: 0x%08x\n", mcause, mepc);
        while(1);
    }
}
