// 简单的JAL+JALR测试
// 测试函数调用和返回机制

.section .text
.globl _start

_start:
    // 初始化
    li x3, 0                // x3 = 0（计数器）

    // 调用函数
    jal ra, test_func       // ra应该 = PC+4

    // 返回后应该执行到这里
    addi x3, x3, 100        // x3 += 100，标记成功返回

    // 结束
    j end_loop

test_func:
    addi x3, x3, 1          // x3 += 1，标记函数被调用
    jalr x0, 0(ra)          // 返回（跳转到ra）

end_loop:
    j end_loop              // 死循环
