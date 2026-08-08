# 🔴 LUI Bug 的根本原因

## 发现

**PC=0x2c (LUI指令) 根本没有到达 WB 阶段！**

从寄存器写回日志看：
```
[2895000] WB: PC=00000000, rd=x 2, data=00010000  # _start: lui sp,0x10  ✅
[2905000] WB: PC=00000004, rd=x 3, data=00001004  # auipc gp,0x1      ✅
[2915000] WB: PC=00000008, rd=x 3, data=00000890  # addi gp,gp,-1908  ✅
[2925000] WB: PC=0000000c, rd=x 5, data=00000090  # li t0,144         ✅
[2935000] WB: PC=00000010, rd=x 6, data=00000090  # li t1,144         ✅
... (BSS 清零循环)
[3135000] WB: PC=00000024, rd=x 1, data=00000028  # jal main          ✅
[3175000] WB: PC=00000030, rd=x14, data=00000004  # addi a4,a4,4      ❌ (重复)
```

**注意**：
- PC 从 0x24 (jal) 直接跳到 0x30 (addi)
- **PC=0x2c (lui a4,0x10010) 被跳过了！**

## 根本原因

### 原因 1：分支预测错误 ⭐⭐⭐⭐⭐ (最可能)

`jal main` 跳转到 0x2c，但**分支预测器可能预测错误**，导致：
1. 预取了错误的指令
2. 发现预测错误后冲刷了流水线
3. LUI 指令在冲刷中被丢弃

### 原因 2：Cache Miss

ICache 在 0x2c 发生 miss，取指失败。

### 原因 3：流水线冒险

JAL 之后的指令被错误地冲刷。

## 验证方法

创建一个不使用跳转的测试程序：

```c
// test_lui_only.c
int main(void) {
    register int a4 asm("a4");
    asm volatile("lui %0, 0x10010" : "=r"(a4));
    asm volatile("addi %0, %0, 4" : "+r"(a4));
    
    if (a4 == 0x10010004) {
        while(1);  // 成功
    } else {
        while(1);  // 失败 (a4 != 0x10010004)
    }
}
```

或者更简单，直接在 _start 中测试 LUI，不经过任何跳转。

## 下一步

1. 检查分支预测器和跳转逻辑
2. 检查 jal 之后的流水线冲刷条件
3. 验证 ICache 在跳转目标处的行为
