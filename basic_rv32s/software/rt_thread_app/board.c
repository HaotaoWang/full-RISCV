#include <rthw.h>
#include <rtthread.h>
#include <stdint.h>

#define CLINT_MTIMECMP_LOW  (*((volatile uint32_t*)0x02004000))
#define CLINT_MTIMECMP_HIGH (*((volatile uint32_t*)0x02004004))
#define CLINT_MTIME_LOW     (*((volatile uint32_t*)0x0200BFF8))
#define CLINT_MTIME_HIGH    (*((volatile uint32_t*)0x0200BFFC))
#define UART_TX_REG     (*((volatile uint32_t*)0x10010000))
#define UART_STATUS_REG (*((volatile uint32_t*)0x10010004))

#define SYSTEM_CLOCK    50000000
#define TICK_CYCLES     (SYSTEM_CLOCK / RT_TICK_PER_SECOND)

extern int _end;

static uint64_t next_tick;

static uint64_t clint_mtime_read(void)
{
    uint32_t high;
    uint32_t low;
    uint32_t high_check;

    do {
        high = CLINT_MTIME_HIGH;
        low = CLINT_MTIME_LOW;
        high_check = CLINT_MTIME_HIGH;
    } while (high != high_check);

    return ((uint64_t)high << 32) | low;
}

static void clint_mtimecmp_write(uint64_t value)
{
    /* RV32 requires this order to avoid a transient timer interrupt while
       updating the two halves of mtimecmp. */
    CLINT_MTIMECMP_HIGH = UINT32_MAX;
    CLINT_MTIMECMP_LOW = (uint32_t)value;
    CLINT_MTIMECMP_HIGH = (uint32_t)(value >> 32);
}

void rt_hw_console_output(const char *str)
{
    while (*str) {
        if (*str == '\n') {
            while (UART_STATUS_REG & 0x01);
            UART_TX_REG = '\r';
            /* Wait a few cycles to ensure UART_busy becomes 1 before the next check */
            for (volatile int i = 0; i < 10; i++);
        }
        while (UART_STATUS_REG & 0x01);
        UART_TX_REG = *str++;
        /* Wait a few cycles to ensure UART_busy becomes 1 before the next check */
        for (volatile int i = 0; i < 10; i++);
    }
}

void rt_hw_board_init(void)
{
    /* Configure SysTick */
    next_tick = clint_mtime_read() + TICK_CYCLES;
    clint_mtimecmp_write(next_tick);

    /* Enable Machine Timer Interrupt (MTIE) in mie register */
    __asm__ volatile(
        "li t0, 0x80\n\t"
        "csrs mie, t0"
    );


#ifdef RT_USING_HEAP
    /* Initialize System Heap */
    rt_system_heap_init((void*)&_end, (void*)(0x00000000 + 64*1024 - 4096));
#endif
}

void system_trap_handler(rt_ubase_t mcause, rt_ubase_t mepc, rt_ubase_t sp)
{
    /* mcause bit 31 indicates interrupt */
    if (mcause & 0x80000000) {
        rt_ubase_t exception_code = mcause & 0x7FFFFFFF;
        if (exception_code == 7) { /* Machine Timer Interrupt */
            uint64_t now = clint_mtime_read();
            do {
                next_tick += TICK_CYCLES;
            } while ((int64_t)(next_tick - now) <= 0);
            clint_mtimecmp_write(next_tick);
            rt_tick_increase();
        }
    } else {
        /* Keep enough context to distinguish a bad JALR target from stack
           corruption.  sp points at the frame built by trap_entry and ra is
           stored in word 1 of that frame. */
        rt_ubase_t mtval;
        rt_ubase_t mstatus;
        rt_ubase_t saved_ra = ((rt_ubase_t *)sp)[1];
        rt_ubase_t interrupted_sp = sp + 32 * sizeof(rt_ubase_t);

        __asm__ volatile("csrr %0, mtval" : "=r"(mtval));
        __asm__ volatile("csrr %0, mstatus" : "=r"(mstatus));

        rt_kprintf("Exception! mcause: 0x%08x, mepc: 0x%08x\n",
                   mcause, mepc);
        rt_kprintf("           mtval: 0x%08x, mstatus: 0x%08x\n",
                   mtval, mstatus);
        rt_kprintf("           ra: 0x%08x, sp: 0x%08x, frame: 0x%08x\n",
                   saved_ra, interrupted_sp, sp);
        while(1);
    }
}
