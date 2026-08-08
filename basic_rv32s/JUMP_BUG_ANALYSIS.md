# 🔴 新发现的 Bug

## 问题

修复 LUI 被跳过后，出现了新问题：

**PC=0x30 (ADDI) 执行时，`EX_jump=1`，导致错误跳转到 0x28！**

```
[3185000] AT_0x30: next_pc=00000028, jump=1, branch=0
```

## 根本原因

当我移除了 `if (trap_done && EX_jump)` 触发的冲刷后：

```verilog
// 修复前：
if (trap_done && (branch_prediction_miss || EX_jump)) begin
    IF_ID_flush = 1'b1;
    ID_EX_flush = 1'b1;
end

// 修复后：
if (trap_done && branch_prediction_miss) begin
    IF_ID_flush = 1'b1;
    ID_EX_flush = 1'b1;
end
```

**副作用**：JAL 指令之后的指令（LUI）在 ID 阶段时，控制单元仍然基于**上一条指令（JAL）的 opcode** 生成了 `jump=1` 信号！

## 时序分析

```
周期 N:
  - IF: LUI (0x2c)
  - ID: JAL (0x24) → jump=1
  - EX: ...
  
周期 N+1:
  - IF: ADDI (0x30)
  - ID: LUI (0x2c) → 但 control unit 可能还在处理旧信号
  - EX: JAL → EX_jump=1, 跳转到 0x2c
  
周期 N+2:
  - IF: LUI (0x2c) ← 重新取指
  - ID: ADDI (0x30) → 继承了错误的 jump 信号？
  - EX: LUI → EX_jump=0
```

## 正确的修复方案

**方案 A**：保持原来的冲刷逻辑，但只冲刷**错误的指令**

跳转指令在 EX 阶段执行时，**IF 阶段的指令是错误的**（应该是跳转目标，但实际取的是 PC+4）。

需要：
1. 检测 IF 阶段取的是否是错误的指令
2. 只有当取指错误时才冲刷

**方案 B**：使用分支预测器

让分支预测器预测 JAL/JALR 的跳转目标，这样 IF 阶段就能正确取指。

**方案 C**：在 ID 阶段就处理跳转

将 JAL/JALR 的跳转判断提前到 ID 阶段，避免延迟槽问题。

## 临时解决方案

先测试使用简单的直线代码（无跳转）验证 LUI 是否真的修复了。
