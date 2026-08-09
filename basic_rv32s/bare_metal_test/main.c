typedef unsigned int uint32_t;

#define UART_TX_REG     (*((volatile uint32_t*)0x10010000))
#define UART_STATUS_REG (*((volatile uint32_t*)0x10010004))
#define LED_REG         (*((volatile uint32_t*)0x10020000))

void delay(int count) {
    for (volatile int i = 0; i < count; i++);
}

void print_char(char c) {
    while (UART_STATUS_REG & 0x01);
    UART_TX_REG = c;
    /* Wait a few cycles to ensure UART_busy goes high */
    delay(10);
}

void print_str(const char *str) {
    while (*str) {
        print_char(*str++);
    }
}

int main(void) {
    int counter = 0;
    while (1) {
        print_str("Hello from bare-metal C!\r\n");
        LED_REG = counter & 0x0F;
        counter++;
        delay(1000000); // long delay
    }
    return 0;
}
