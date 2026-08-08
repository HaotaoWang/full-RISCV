#ifndef RT_CONFIG_H__
#define RT_CONFIG_H__

/* RT-Thread version information */
#define RT_THREAD_PRIORITY_MAX  32
#define RT_TICK_PER_SECOND      1000
#define RT_ALIGN_SIZE           4
#define RT_NAME_MAX             8
#define RT_USING_COMPONENTS_INIT
#define RT_USING_USER_MAIN
#define RT_MAIN_THREAD_STACK_SIZE 1024
#define RT_MAIN_THREAD_PRIORITY 10

/* Kernel Device Object */
#define RT_USING_DEVICE
#define RT_USING_CONSOLE
#define RT_CONSOLEBUF_SIZE          128
#define RT_CONSOLE_DEVICE_NAME      "uart"

/* IPC */
#define RT_USING_SEMAPHORE
#define RT_USING_MUTEX
#define RT_USING_EVENT
#define RT_USING_MAILBOX
#define RT_USING_MESSAGEQUEUE

/* Memory Management */
#define RT_USING_MEMPOOL
#define RT_USING_SMALL_MEM
#define RT_USING_HEAP

#endif
