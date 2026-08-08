// 最小化的 JAL + LUI 测试
// 目标：验证 JAL 后的 LUI 指令是否被正确执行

.section .text
.globl _start

_start:
    // 初始化栈指针
    lui sp, 0x10000

    // 测试 JAL 跳转到 main
    jal ra, main        // JAL 指令

    // 如果 LUI 被跳过，main 函数会出错
    j loop              // 死循环

main:
    // 第一条指令是 LUI - 这是关键测试点
    lui a0, 0x12345     // 如果这条被跳过，a0 会是错误值
    addi a0, a0, 0x678  // a0 = 0x12345678

    // 写入 GPIO 验证
    lui a1, 0x10010
    sw a0, 0(a1)

    ret

loop:
    j loop
