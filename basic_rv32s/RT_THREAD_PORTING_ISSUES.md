# RT-Thread 移植问题诊断报告

> 项目：basic_rv32s RISC-V 处理器  
> RT-Thread 版本：RT-Thread Nano  
> 分析日期：2026-08-08

---

## 📋 地址映射确认

从 `RV32_SoC_AXI_Top.v:274-275` 可以看到：

```verilog
.M_BASE_ADDR({32'h02000000, 32'h00000000}),
.M_ADDR_WIDTH({32'd24, 32'd16})
```

**地址空间分配：**
- **M0 (RAM)**：`0x0000_0000 ~ 0x0000_FFFF` (64KB, ADDR_WIDTH=16)
- **M1 (CLINT)**：`0x0200_0000 ~ 0x02FF_FFFF` (16MB, ADDR_WIDTH=24)

**board.c 中的地址定义是正确的：**
```c
#define CLINT_MTIMECMP  (*((volatile uint32_t*)0x02004000))  // 基地址 + 0x4000
#define CLINT_MTIME     (*((volatile uint32_t*)0x0200BFF8))  // 基地址 + 0xBFF8
```

✅ **地址映射正确，无需修改。**

---

## 🔴 核心问题汇总

### **问题 1：栈帧结构不匹配** ⭐⭐⭐⭐⭐ (最严重)

**症状：** 上下文切换时寄存器恢复错误，导致程序崩溃或行为异常。

**根本原因：**

`startup.S` 的 `trap_entry` 和 `context_gcc.S` 的 `rt_hw_context_switch_exit` 期望的栈帧格式不一致。

**RT-Thread 标准栈帧（cpuport.c:23-91）：**
```c
struct rt_hw_stack_frame {
    rt_ubase_t epc;        // sp[0]  - mepc
    rt_ubase_t ra;         // sp[1]  - x1
    rt_ubase_t mstatus;    // sp[2]  - MIE/MPIE 状态位
    rt_ubase_t gp;         // sp[3]  - x3
    rt_ubase_t tp;         // sp[4]  - x4
    ...                    // sp[5-31] - x5-x31
};
```

**原 startup.S 的问题：**
- sp[2] 保存完整的 mstatus，但 RT-Thread 期望只有 MIE/MPIE 位信息
- 没有明确处理 MIE → MPIE 的转换
- sp 索引可能错位

**解决方案：** 使用修正后的 `startup_fixed.S`（已创建）

---

### **问题 2：全局中断未使能** ⭐⭐⭐⭐⭐ (最严重)

**症状：** 定时器中断永远不会触发，RT-Thread 无法调度。

**根本原因：**

`board.c:33-36` 只使能了 `mie.MTIE` (机器定时器中断使能)，但没有使能 `mstatus.MIE` (全局中断使能位)。

**RISC-V 中断触发条件：**
```
中断触发 = mstatus.MIE && mie.MTIE && timer_irq
```

**原代码：**
```c
__asm__ volatile(
    "li t0, 0x80\n\t"
    "csrs mie, t0"      // 只设置了 MTIE
);
// 缺少: csrsi mstatus, 0x8  <- 使能全局中断
```

**已修复：** board.c 已更新，添加了全局中断使能。

---

### **问题 3：堆栈空间不足** ⭐⭐⭐

**症状：** 栈溢出导致数据损坏或硬件异常。

**根本原因：**

RT-Thread 需要多个线程栈（主线程、空闲线程、定时器线程），原配置只有 2KB。

**原配置（link.lds）：**
```ld
.stack ORIGIN(RAM) + LENGTH(RAM) - 2K : {
    PROVIDE( _sp = . + 2K );  // 只有 2048 字节
}
```

**RT-Thread 堆栈需求估算：**
- 主线程栈：1024 字节（rtconfig.h 配置）
- 空闲线程栈：~256 字节
- 中断栈：~512 字节
- 堆内存：动态分配对象

**已修复：** link.lds 已更新为 4KB。

---

### **问题 4：堆内存范围配置** ⭐⭐

**原配置：**
```c
rt_system_heap_init((void*)&_end, (void*)(0x00000000 + 64*1024 - 2048));
```

**问题：** 堆的结束地址侵入了栈空间（栈现在是 4KB）。

**已修复：** board.c 已更新为：
```c
rt_system_heap_init((void*)&_end, (void*)(0x00000000 + 64*1024 - 4096));
```

---

### **问题 5：startup.S 中未使能全局中断** ⭐⭐⭐

**原 startup.S：**
在跳转到 `entry` 之前没有使能 `mstatus.MIE`。

**已修复：** startup_fixed.S 添加了：
```asm
/* Enable global interrupts (mstatus.MIE) */
li t0, 0x8
csrs mstatus, t0
```

---

## ✅ 修复方案

### **1. 替换启动文件**

```bash
cd basic_rv32s/software/rt_thread_app
mv startup.S startup_old.S
mv startup_fixed.S startup.S
```

### **2. 重新编译**

```bash
cd basic_rv32s/software/rt_thread_app
make clean
make
```

### **3. 运行仿真测试**

```bash
cd basic_rv32s
iverilog -o sim testbenches/RV32_SoC_AXI_tb.v RV32_SoC_AXI_Top.v modules/*.v
vvp sim
```

**预期输出：**
```
Hello, RT-Thread on basic_rv32s!
Tick: 0
Tick: 1000
Tick: 2000
...
```

---

## 🔍 调试建议

### **1. 验证中断是否触发**

在 `system_trap_handler` 添加调试输出：

```c
void system_trap_handler(rt_ubase_t mcause, rt_ubase_t mepc, rt_ubase_t sp)
{
    if (mcause & 0x80000000) {
        rt_ubase_t exception_code = mcause & 0x7FFFFFFF;
        rt_kprintf("IRQ: mcause=0x%08x, code=%d\n", mcause, exception_code);
        if (exception_code == 7) {
            CLINT_MTIMECMP += TICK_CYCLES;
            rt_tick_increase();
        }
    } else {
        rt_kprintf("Exception! mcause: 0x%08x, mepc: 0x%08x\n", mcause, mepc);
        while(1);
    }
}
```

### **2. 检查 CLINT 寄存器值**

在 `rt_hw_board_init` 后添加：

```c
rt_kprintf("CLINT_MTIME     = %d\n", CLINT_MTIME);
rt_kprintf("CLINT_MTIMECMP  = %d\n", CLINT_MTIMECMP);
rt_kprintf("mstatus.MIE     = %d\n", (read_csr(mstatus) >> 3) & 1);
rt_kprintf("mie.MTIE        = %d\n", (read_csr(mie) >> 7) & 1);
```

### **3. 验证栈帧正确性**

在 `trap_entry` 进入时打印 sp 值：

```asm
trap_entry:
    addi sp, sp, -32 * 4
    
    /* Debug: 打印栈指针 */
    mv a0, sp
    call print_sp_debug  // 需要在 C 中实现
    
    ...
```

---

## 📊 预期性能指标

修复后，RT-Thread 应该能够：

✅ **启动成功** - 打印 "Hello, RT-Thread"  
✅ **定时器中断** - 每秒触发 1000 次 (RT_TICK_PER_SECOND=1000)  
✅ **线程调度** - rt_thread_mdelay(1000) 正常工作  
✅ **打印输出** - UART 输出 tick 计数  

**资源占用：**
- ROM (代码段)：~12KB  
- RAM (数据+BSS+堆+栈)：~8KB  
- 剩余堆空间：~52KB (64KB - 代码 - 栈)  

---

## 🎯 后续优化方向

1. **添加更多外设驱动**
   - GPIO 驱动（LED 闪烁）
   - UART 驱动（完整收发）

2. **性能优化**
   - 减小 RT_TICK_PER_SECOND 到 100 (降低中断频率)
   - 优化 CLINT 访问延迟

3. **添加线程示例**
   - 创建多个线程验证调度
   - 测试信号量、互斥锁等 IPC 机制

4. **上板验证**
   - 生成 bitstream
   - 下载到 FPGA
   - 通过 UART 观察输出

---

## 📚 参考资料

- RT-Thread Nano 移植指南：https://www.rt-thread.org/document/site/
- RISC-V 特权级规范：https://riscv.org/technical/specifications/
- AXI4 总线协议：https://developer.arm.com/documentation/ihi0022/
- CLINT 规范：RISC-V Platform-Level Interrupt Controller Specification

---

## 🚀 快速修复脚本

```bash
#!/bin/bash
cd basic_rv32s/software/rt_thread_app

# 1. 备份原文件
cp startup.S startup_backup.S
cp board.c board_backup.c
cp link.lds link_backup.lds

# 2. 使用修复后的文件
cp startup_fixed.S startup.S

# 3. 重新编译
make clean
make

# 4. 生成 hex 文件
python makehex.py rtthread.bin rtthread.hex

echo "修复完成！请运行仿真测试。"
```

---

**修复完成后，如果仍有问题，请检查：**

1. ✅ 中断是否真的触发了？（添加 debug 输出）
2. ✅ CLINT 地址访问是否正常？（波形图查看 AXI 事务）
3. ✅ 栈指针是否在合法范围内？（0x0000_F000 ~ 0x0001_0000）
4. ✅ RT-Thread 初始化是否成功？（entry 函数是否被调用）

祝移植顺利！🎉
