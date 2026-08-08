#include <rtthread.h>

int main(void)
{
    rt_kprintf("Hello, RT-Thread on basic_rv32s!\n");
    
    while (1)
    {
        rt_kprintf("Tick: %d\n", rt_tick_get());
        rt_thread_mdelay(1000); // 延时 1000ms (1秒)
    }
    
    return 0;
}
