int main(void) {
    // 顺序执行，无跳转
    volatile int x1, x2, x3;
    
    // 测试 LUI
    asm volatile("lui a4, 0x12345");
    asm volatile("mv %0, a4" : "=r"(x1));
    
    asm volatile("addi a4, a4, 0x678");
    asm volatile("mv %0, a4" : "=r"(x2));
    
    if (x1 == 0x12345000 && x2 == 0x12345678) {
        while(1);  // 成功
    } else {
        x3 = 0xDEAD;  // 失败
        while(1);
    }
}
