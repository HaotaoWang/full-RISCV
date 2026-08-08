#include <stdint.h>

#define UART_TX_REG     (*((volatile uint32_t*)0x10010000))
#define UART_STATUS_REG (*((volatile uint32_t*)0x10010004))

void uart_putc(char c) {
    while (UART_STATUS_REG & 0x01);
    UART_TX_REG = c;
}

int main(void) {
    // 极简测试：只输出 "Hi\n"，完全不使用循环或复杂逻辑
    uart_putc('H');
    uart_putc('i');
    uart_putc('\n');

    // 死循环（等待观察输出）
    while(1);

    return 0;
}
