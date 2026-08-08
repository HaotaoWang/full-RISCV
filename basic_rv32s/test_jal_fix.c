// 测试 JAL 跳转后 LUI 指令是否被正确执行
// 这是修复前会失败的最小测试用例

int main() {
    // 这个函数调用会产生 JAL 指令
    // JAL 后的第一条指令通常是 LUI（加载大立即数）
    volatile unsigned int *gpio = (unsigned int *)0x10010004;

    // 写入一个大数值，编译器会生成 LUI + ADDI
    *gpio = 0x12345678;

    // 如果 LUI 被跳过，这个值会是错误的
    return (*gpio == 0x12345678) ? 0 : 1;
}

void _start() {
    int result = main();
    // 将结果写到 GPIO，用于硬件验证
    volatile unsigned int *gpio = (unsigned int *)0x10010000;
    *gpio = result;

    // 死循环
    while(1);
}
