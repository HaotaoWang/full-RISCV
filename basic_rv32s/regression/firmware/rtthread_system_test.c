#include <rtthread.h>
#include <stdint.h>

/* Testbench-visible state. These variables are deliberately kept outside the
 * production application and exist only in the regression firmware. */
volatile uint32_t regression_ready;
volatile uint32_t regression_delay_count;
volatile uint32_t regression_delay_fail;
volatile uint32_t regression_tick_before;
volatile uint32_t regression_tick_after;

int main(void)
{
    regression_ready = 0x52545359u; /* "RTSY" */
    rt_kprintf("RT system regression ready\n");

    while (1)
    {
        rt_tick_t before = rt_tick_get();
        rt_tick_t after;

        regression_tick_before = before;
        rt_thread_mdelay(2);
        after = rt_tick_get();
        regression_tick_after = after;

        if ((rt_tick_t)(after - before) < 2u)
            regression_delay_fail++;
        else
            regression_delay_count++;
    }
}
