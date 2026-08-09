// 测试JAL函数调用和返回
// 模拟RT-Thread启动流程中的函数调用

    .section .text
    .globl _start

_start:
    // 设置栈指针
    lui sp, 0x10000

    // 调用函数
    jal ra, test_func    // 应该跳转到test_func，ra = PC+4

    // 返回后执行
    addi x3, x3, 100     // x3 += 100，标记返回成功

    // 死循环
loop_end:
    j loop_end

test_func:
    addi x3, x3, 1       // x3 += 1，标记函数被调用
    jalr x0, 0(ra)       // 返回到调用者
