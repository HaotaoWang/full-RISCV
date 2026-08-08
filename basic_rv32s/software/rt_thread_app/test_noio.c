#include <stdint.h>

int main(void) {
    // 完全不访问任何外设，只做计算
    volatile int sum = 0;

    // 简单的计算：1+2+3+...+10 = 55
    for (volatile int i = 1; i <= 10; i++) {
        sum += i;
    }

    // sum 现在应该是 55
    // 死循环（使用 sum 避免被优化掉）
    while(sum == 55);

    return 0;
}
