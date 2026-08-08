#include <stdint.h>

#define UART_TX_REG     (*((volatile uint32_t*)0x10010000))
#define UART_STATUS_REG (*((volatile uint32_t*)0x10010004))

void uart_putc(char c) {
    while (UART_STATUS_REG & 0x01);
    UART_TX_REG = c;
}

void uart_puts(const char *s) {
    while (*s) {
        if (*s == '\n') uart_putc('\r');
        uart_putc(*s++);
    }
}

int main(void) {
    uart_puts("Hello from test program!\n");

    // 无限循环
    while(1) {
        for (volatile int i = 0; i < 1000000; i++);
        uart_putc('.');
    }

    return 0;
}
