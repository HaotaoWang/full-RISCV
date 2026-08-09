# RT-Thread调试进展报告 - JAL修复后的状态

## 🎯 已完成的修复

### 修复1: ID_jump_target定义和计算
```verilog
wire [XLEN-1:0] ID_jump_target;
assign ID_jump_target = (opcode == `OPCODE_JAL)  ? (ID_pc + imm) :
                        (opcode == `OPCODE_JALR) ? (read_data1 + imm) : 32'h0;
```
✅ JAL跳转目标正确计算

### 修复2: Control_Unit的pc_stall逻辑
```verilog
// 当跳转指令时，即使IF_ID_stall也要允许PC更新
pc_stall = (!write_done || !trap_done || !csr_ready || (IF_ID_stall && !is_jump));
```
✅ JAL时PC能够更新

### 修复3: Hazard_Unit的IF_ID_stall逻辑
```verilog
// ICache miss时，如果有ID_jump，不stall IF_ID
IF_ID_stall = ID_jump ? 1'b0 : 1'b1;
```
✅ JAL跳转后新指令能进入ID阶段

## 📊 当前测试结果

### ✅ 成功的部分
1. ✅ CPU执行了20,000条指令
2. ✅ PC正常推进（0x5000 → 0xa000）
3. ✅ JAL指令成功执行：
   - 0x3c → 0x134 (entry函数)
   - 0x13c → 0x26c0 (其他函数)
4. ✅ 没有卡在死循环
5. ✅ 没有检测到trap/异常

### ❌ 问题
1. ❌ **没有JALR执行** - 函数调用了但从未返回！
2. ❌ 没有UART输出
3. ❌ RT-Thread没有启动到打印阶段

## 🔍 根本原因

**JALR指令没有执行！**

可能原因：
1. **JALR指令本身有bug** - ID_jump_target计算错误或PC跳转失败
2. **函数内部出错** - 在到达JALR返回指令之前就崩溃或死循环
3. **JALR被当作其他指令** - opcode识别错误

## 🎯 下一步调试计划

### 优先级1: 验证JALR基本功能
创建简单测试：
```asm
jal ra, func     # 跳转到函数
addi x3, x3, 100 # 返回后执行
j loop

func:
    addi x3, x3, 1
    jalr x0, 0(ra)  # 返回
```

### 优先级2: 追踪entry函数内部执行
- 查看entry函数的反汇编
- 确认是否有JALR指令
- 追踪函数内部的PC变化

### 优先级3: 检查JALR的ID_jump_target计算
- JALR: target = rs1 + imm
- 确保read_data1在ID阶段可用
- 检查是否有数据冒险

## 📝 修改文件清单

1. `modules/RV32I46F_5SP_MMIO.v` - 添加ID_jump_target定义和计算
2. `modules/Control_Unit.v` - 修复pc_stall逻辑
3. `modules/Hazard_Unit.v` - 修复IF_ID_stall逻辑（ICache miss时）
4. `testbenches/RV32_SoC_AXI_tb.v` - 添加详细调试输出

## 🤔 分析

虽然JAL现在能够跳转，但RT-Thread仍然无法启动，因为：
- **函数无法返回** - 这是致命的
- 任何C代码都依赖函数调用和返回
- JALR失败 = RT-Thread完全无法运行

**结论**: 必须先修复JALR，才能继续调试RT-Thread。
