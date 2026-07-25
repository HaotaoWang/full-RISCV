# basic_rv32s 项目复盘与下一步计划

> 基于 2026-07-25 的项目状态分析  
> Git 最新提交: `67543ec feat: 完全跑通 AXI + 特权级跳转，硬件上板成功点亮四个 LED`

---

## 📊 项目当前状态总结

### ✅ 已完成的核心功能

#### 1. **基础处理器架构**（完成度：100%）

你已经实现了完整的 RISC-V 处理器系列：

| 处理器 | ISA | 特性 | 状态 |
|--------|-----|------|------|
| RV32I37F | RV32I (37条指令) | 单周期基础架构 | ✅ 完成 |
| RV32I43F | RV32I + Zicsr (43条) | 添加 CSR 支持 | ✅ 完成 |
| RV32I46F | RV32I + Zicsr + 异常 (46条) | 异常检测与处理 | ✅ 完成 |
| RV32I46F_5SP | RV32I + Zicsr + 流水线 | 5级流水线 + 分支预测 | ✅ 完成 |
| RV32I46F_5SP_MMIO | + MMIO | UART + LED 外设 | ✅ 完成 |

**性能指标：**
- Dhrystone 2.1: **1.11 DMIPS/MHz** @ 50MHz
- CoreMark: **1.10 CoreMark/MHz** @ 50MHz
- CPI: ~1.61 cycles/instruction

#### 2. **特权级架构**（最新进展：✅ 完成）

从最近的 Git 提交来看，你刚刚完成了：

```
67543ec - feat: 完全跑通 AXI + 特权级跳转，硬件上板成功点亮四个 LED
```

**已实现的特权级功能：**
- ✅ **M-Mode (机器模式)**：完整实现
- ✅ **S-Mode (监督者模式)**：已实现并验证
- ✅ **U-Mode (用户模式)**：支持（通过 MMU PTE.U 位判断）
- ✅ **特权级切换**：MRET / SRET 指令
- ✅ **CSR 扩展**：
  - M-Mode: mstatus, mtvec, mepc, mcause, mtval, mscratch, medeleg, mideleg
  - S-Mode: sstatus, stvec, sepc, scause, stval, sscratch, **satp**

#### 3. **MMU（内存管理单元）**（最新添加：⚠️ 基础完成，有改进空间）

**当前实现：**
- ✅ Sv32 分页机制（RISC-V Privileged Spec）
- ✅ ITLB（指令 TLB）：1-entry
- ✅ DTLB（数据 TLB）：1-entry
- ✅ 虚拟地址到物理地址转换
- ✅ Page Fault 检测（指令/加载/存储）
- ✅ 权限检查：
  - Supervisor/User 模式区分
  - R/W/X 权限位验证
  - mstatus.SUM（Supervisor User Memory access）支持
  - mstatus.MXR（Make eXecutable Readable）支持
- ✅ satp CSR（控制 MMU 开关和页表基址）
- ✅ 通过 CSR 接口预加载 TLB（软件填充 TLB 的 backdoor 机制）

**模块文件：**
- `modules/MMU.v` - MMU 主模块
- `modules/CSR_File.v` - 扩展了 TLB 写入接口（CSR 0x803-0x805）

**验证状态：**
- ✅ 硬件上板测试通过（Kintex-7 FPGA）
- ✅ M-Mode -> S-Mode 特权级跳转成功
- ✅ MMU 地址转换正确（VA 0x8000_0000 -> PA 0x1002_0000）
- ✅ LED 外设访问成功

#### 4. **AXI4 总线架构**（最新升级：✅ 完成）

从 Git 历史看到的进展：

```
6a829a1 - Feat: 成功集成 ICache 与 DCache，支持 AXI4 协议
c5e0aa3 - Phase 2: Migrate to Full AXI4 bus, add ICache and axi_ram_init
```

**已实现：**
- ✅ **ICache（指令缓存）**：ultraembedded 的 icache 模块
- ✅ **DCache（数据缓存）**：ultraembedded 的 dcache 模块
- ✅ **AXI4 Interconnect**：2 Master (IF + MEM) -> 1 Slave (RAM)
- ✅ **AXI RAM with init**：支持 .hex 文件初始化
- ✅ **Cache coherency 修复**：MMIO 地址标记为 uncacheable

**今天刚修复的 Bug：**
- ✅ 修复了 DCache cacheable 判断逻辑（MMIO 区域不可缓存）
- 这解决了 LED 需要 20 秒才能点亮的问题

#### 5. **FPGA 验证**（✅ 完整验证）

**目标平台：**
- Digilent Nexys Video (Xilinx Artix-7 XC7A200T)
- Kintex-7 MK160FA (你当前使用的板子)

**综合结果：**
- LUTs: ~11,280（包含 Dhrystone 程序）
- FFs: ~1,636
- 频率: 50 MHz
- 资源: 所有内存都使用 LUT-based distributed RAM（没有用 BRAM）

**外设支持：**
- ✅ UART TX (115200 baud)
- ✅ 4x LED
- ✅ 按钮输入
- ✅ 时钟分频与复位同步

---

## 🎯 当前架构的特点

### 核心设计亮点

1. **完整的 5 级流水线**
   - IF -> ID -> EX -> MEM -> WB
   - 动态分支预测（2-bit FSM）
   - 数据前递（Forwarding）
   - 冒险检测与停顿（Hazard Detection）

2. **特权级与 MMU 集成**
   - 三级特权：M/S/U Mode
   - Sv32 虚拟内存
   - 异常与中断支持
   - Trap Handler 完整实现

3. **高性能缓存系统**
   - 分离的 I/D Cache
   - AXI4 标准总线
   - Write-through / Write-back 策略
   - Uncacheable 区域支持

4. **教学友好的设计**
   - 模块化设计，每个模块职责清晰
   - 完整的文档和注释
   - 信号级框图
   - 逐步演进的架构（37F -> 43F -> 46F -> 5SP）

---

## ⚠️ 当前发现的问题与限制

### 1. **MMU/TLB 的限制**

**问题：**
- ✅ 已修复：Cache coherency 问题（MMIO 被错误缓存）
- ⚠️ TLB 太小：只有 1-entry ITLB 和 1-entry DTLB
- ⚠️ 没有 Page Table Walker (PTW)：
  - TLB miss 直接触发 Page Fault
  - 需要软件通过 CSR 手动填充 TLB
  - 无法支持标准的 OS（Linux 等）

**影响：**
- 无法运行需要多个虚拟地址映射的程序
- 频繁的 TLB miss 会导致性能下降
- 不支持动态页表遍历

### 2. **内存系统的限制**

**问题：**
- ⚠️ 所有内存都是 LUT-based distributed RAM
  - 浪费大量 LUT 资源
  - 限制了可用内存大小
  - 没有利用 FPGA 的 BRAM 资源

**当前配置：**
- RAM_ADDR_WIDTH = 16 bit → 64KB RAM
- 这在 LUT 实现下是合理的，但如果用 BRAM 可以轻松扩展到几 MB

### 3. **性能瓶颈**

**观察到的问题：**
- CPI = 1.61（理想 5 级流水线应该接近 1.0）
- 可能的原因：
  - Cache miss 惩罚
  - 分支预测失误
  - 数据冒险导致的停顿
  - CSR 访问的延迟

---

## 📋 README 中的 Roadmap 分析

### ✅ 已完成项

```markdown
✅ Complete basic_RV32s repository structure  
✅ Contribute riscv/learn as tutorial resource  
✅ Writing Paper about this repository  ✨ISOCC 2025 Accepted (Oral)
✅ Translate Korean resources to English  
✅ Resolve issues of 46F5SP architecture  
✅ Benchmark with Coremark
```

**新增完成项（基于最新进展）：**
- ✅ **集成 MMU 和特权级架构**
- ✅ **升级到 AXI4 总线**
- ✅ **集成 ICache 和 DCache**
- ✅ **修复 Cache coherency 问题**
- ✅ **在 Kintex-7 FPGA 上验证**

### 📋 进行中/未完成项

```markdown
📋 Performance Enhancement by Optimize critical paths, advanced core architecture  
   -> [ima_make_rv64](https://github.com/RISC-KC/ima_make_rv64)
📋 Optimize FPGA resource utilization
```

---

## 🚀 下一步建议计划

基于你已经完成的工作和当前的技术栈，这里是我建议的优先级排序：

### 🔥 高优先级（短期，1-2周）

#### 1. **扩展 TLB 大小**（关键性能改进）

**目标：** 将 TLB 从 1-entry 扩展到 8-16 entries

**理由：**
- 当前的 1-entry TLB 是最大的性能瓶颈
- 对于任何稍微复杂的程序（跨多个页面），1-entry 远远不够
- 实现相对简单，收益明显

**实现方案：**

**方案 A：简单的全相联 TLB（推荐）**
```verilog
// 8-entry 全相联 TLB，Round-Robin 替换策略
parameter TLB_ENTRIES = 8;

reg [TLB_ENTRIES-1:0] itlb_valid;
reg [19:0] itlb_vpn [TLB_ENTRIES-1:0];
reg [21:0] itlb_ppn [TLB_ENTRIES-1:0];
reg [9:0]  itlb_flags [TLB_ENTRIES-1:0];
reg [2:0]  itlb_replace_idx;  // Round-Robin 计数器

// TLB 查找（并行比较）
integer i;
reg itlb_hit;
reg [21:0] itlb_hit_ppn;
always @(*) begin
    itlb_hit = 1'b0;
    itlb_hit_ppn = 22'b0;
    for (i = 0; i < TLB_ENTRIES; i = i + 1) begin
        if (itlb_valid[i] && (itlb_vpn[i] == if_vpn)) begin
            itlb_hit = 1'b1;
            itlb_hit_ppn = itlb_ppn[i];
        end
    end
end

// TLB 替换（Round-Robin）
always @(posedge clk) begin
    if (itlb_we) begin
        itlb_valid[itlb_replace_idx] <= 1'b1;
        itlb_vpn[itlb_replace_idx] <= tlb_wvpn;
        itlb_ppn[itlb_replace_idx] <= tlb_wpte[31:10];
        itlb_flags[itlb_replace_idx] <= tlb_wpte[9:0];
        itlb_replace_idx <= itlb_replace_idx + 1;
    end
end
```

**工作量：** 1-2 天
**收益：** TLB miss 率大幅降低，性能提升明显

#### 2. **使用 BRAM 替代 LUT RAM**（资源优化）

**目标：** 将内存从 LUT distributed RAM 迁移到 Block RAM (BRAM)

**理由：**
- 释放大量 LUT 资源用于逻辑
- 可以扩展内存容量（从 64KB 到几 MB）
- Artix-7 XC7A200T 有 365 个 BRAM（13.5 Mb），目前完全没用上

**实现方案：**

在 `axi_ram_init.v` 中添加 BRAM 推断指令：

```verilog
(* ram_style = "block" *) reg [31:0] mem [0:(2**ADDR_WIDTH)-1];
```

或使用 Vivado IP Catalog 的 Block Memory Generator。

**配置建议：**
- IMEM (ROM): 128 KB BRAM（用于更大的程序）
- DMEM (RAM): 256 KB BRAM（用于堆栈和数据）
- 总共: ~384 KB = 96 个 BRAM（只用了 26% 的 BRAM 资源）

**工作量：** 1 天
**收益：** LUT 使用率降低 ~70%，内存容量扩展 6 倍

#### 3. **完善 MMU 测试程序**（验证稳定性）

**目标：** 创建更全面的 MMU 测试套件

**测试内容：**
- ✅ 基础地址转换（已验证）
- [ ] 多页访问（测试 TLB 替换）
- [ ] 权限违规检测
  - U-Mode 访问 S-Mode 页面 → Page Fault
  - 写入只读页面 → Store Page Fault
  - 执行不可执行页面 → Instruction Page Fault
- [ ] mstatus.SUM 和 mstatus.MXR 测试
- [ ] satp 切换（更换页表基址）
- [ ] TLB flush 测试（写 satp 应该使 TLB 失效）

**工作量：** 2-3 天
**收益：** 增强系统可靠性，为操作系统移植做准备

---

### ⚡ 中优先级（中期，2-4周）

#### 4. **实现 Page Table Walker (PTW)**（系统级改进）

**目标：** 实现硬件 PTW，支持自动页表遍历

**理由：**
- 这是运行标准操作系统（如 xv6, Linux）的必要条件
- 消除软件手动填充 TLB 的开销
- 更符合 RISC-V 标准

**实现方案：**

1. **两级页表遍历状态机**
```verilog
localparam PTW_IDLE = 2'b00;
localparam PTW_L1   = 2'b01;  // 访问一级页表
localparam PTW_L2   = 2'b10;  // 访问二级页表
localparam PTW_DONE = 2'b11;

reg [1:0] ptw_state;
reg [31:0] ptw_pte;
wire [31:0] l1_pte_addr = {satp[19:0], va[31:22], 2'b00};
wire [31:0] l2_pte_addr = {ptw_pte[31:10], va[21:12], 2'b00};
```

2. **与 Cache 协作**
- PTW 需要从内存读取 PTE
- 可以通过 DCache 或直接通过 AXI 访问
- 增加一个 AXI Master 端口专门给 PTW

**工作量：** 5-7 天
**收益：** 
- 支持动态页表
- 为操作系统移植打下基础
- 性能提升（减少软件开销）

#### 5. **优化流水线性能**（CPI 优化）

**目标：** 将 CPI 从 1.61 降低到 1.2 以下

**优化方向：**

**5.1 改进分支预测器**
- 当前：2-bit FSM 饱和计数器
- 升级：Branch Target Buffer (BTB) + Return Address Stack (RAS)
- 收益：分支预测准确率从 ~60% 提升到 ~85%

**5.2 减少 Cache Miss 惩罚**
- 实现 Critical Word First
- 非阻塞 Cache（允许 miss 期间继续处理其他请求）

**5.3 优化 CSR 访问**
- 当前 CSR 需要 `csr_ready` 信号，引入停顿
- 优化为单周期 CSR 访问

**工作量：** 3-5 天
**收益：** 性能提升 20-30%

#### 6. **添加更多 CSR 和中断支持**（系统完整性）

**目标：** 实现完整的中断和定时器支持

**需要添加的 CSR：**
- mie, mip（中断使能和挂起）
- sie, sip（S-Mode 中断）
- mtime, mtimecmp（定时器）
- mcounteren, scounteren（计数器访问控制）

**外部中断源：**
- UART RX 中断
- 定时器中断
- 外部按钮中断

**工作量：** 4-6 天
**收益：** 
- 支持抢占式多任务
- 实时响应能力
- 为 RTOS 移植做准备

---

### 🔧 低优先级（长期，1-2月）

#### 7. **扩展 ISA 支持**（功能扩展）

**可选的扩展：**

**7.1 M 扩展（整数乘除法）**
- 你已经有 `Hardware_Multiplier.v`
- 添加：DIV, DIVU, REM, REMU 指令
- 收益：性能提升（避免软件乘除法）

**7.2 A 扩展（原子操作）**
- LR.W / SC.W（Load-Reserved / Store-Conditional）
- AMO*.W（原子内存操作）
- 收益：支持多核同步原语

**7.3 C 扩展（压缩指令）**
- 16 位压缩指令
- 收益：减少代码大小 ~30%

**工作量：** 每个扩展 1-2 周
**收益：** 更完整的 RISC-V 实现，更好的性能和兼容性

#### 8. **移植操作系统**（终极目标）

**8.1 xv6-riscv（推荐起点）**
- MIT 6.S081 课程使用的教学 OS
- 代码量小（~8000 行），易于理解
- 需要：完整的 MMU + PTW + 中断支持

**8.2 RT-Thread**
- 国产 RTOS，文档丰富
- 对硬件要求相对较低
- 社区活跃，容易获得支持

**8.3 Linux（长期目标）**
- 需要更完整的硬件支持（SMP, 外设驱动等）
- 更大的内存（至少 8 MB）
- 可能需要 RV64 架构

**工作量：** 2-4 周（xv6），2-3 月（Linux）
**收益：** 
- 完整的系统级验证
- 教学价值极高
- 可以运行真实应用程序

#### 9. **多核支持**（高级功能）

**目标：** 实现 2-4 核 SMP 系统

**需要添加：**
- 多个 CPU 核心实例
- Cache 一致性协议（MESI/MOESI）
- 核间中断（IPI）
- 原子操作支持（A 扩展）
- 多核启动与同步

**工作量：** 1-2 月
**收益：** 
- 并行性能提升
- 学习多核架构设计
- 论文材料（多核 RISC-V 实现）

---

## 🎓 建议的开发路线图

### 阶段 1：MMU 和性能优化（1-2 周）
```
Week 1:
- [x] 修复 Cache coherency（已完成）
- [ ] 扩展 TLB 到 8-16 entries
- [ ] 迁移到 BRAM

Week 2:
- [ ] 完善 MMU 测试程序
- [ ] 性能分析和优化（CPI 降低）
```

### 阶段 2：系统完整性（2-4 周）
```
Week 3-4:
- [ ] 实现 Page Table Walker
- [ ] 添加中断和定时器支持

Week 5-6:
- [ ] 改进分支预测器
- [ ] 优化 Cache 性能
```

### 阶段 3：操作系统移植（4-8 周）
```
Week 7-10:
- [ ] 移植 xv6-riscv
- [ ] 系统级测试和调试

Week 11-14:（可选）
- [ ] 移植 RT-Thread 或其他 RTOS
- [ ] 添加更多外设驱动
```

### 阶段 4：高级功能（8 周+）
```
Long-term:
- [ ] ISA 扩展（M/A/C）
- [ ] 多核支持
- [ ] Linux 移植
```

---

## 📝 我的建议

基于你当前的进度和已经取得的成果，我建议：

### 🎯 **近期目标（接下来 2 周）**

**重点完成 3 件事：**

1. **扩展 TLB**（2-3 天）
   - 这是性能提升最明显的改进
   - 实现相对简单
   - 为后续工作打好基础

2. **迁移到 BRAM**（1 天）
   - 释放 LUT 资源
   - 扩展内存容量
   - 为运行更大程序做准备

3. **完善 MMU 测试**（2-3 天）
   - 验证系统稳定性
   - 发现潜在问题
   - 为 OS 移植做准备

### 🚀 **中期目标（接下来 1 月）**

**实现 Page Table Walker + 中断支持**
- 这是运行操作系统的必要条件
- 工作量适中，有挑战性
- 完成后可以尝试移植 xv6

### 🌟 **长期愿景**

**成功移植 xv6-riscv**
- 这将是一个里程碑式的成就
- 完整验证你的处理器设计
- 极高的教学和展示价值
- 可以作为论文素材

---

## 📊 技术债务清单

需要注意的遗留问题：

1. ⚠️ **内存系统**
   - 当前使用 LUT RAM，需要迁移到 BRAM
   - 内存容量太小（64KB）

2. ⚠️ **TLB 大小**
   - 1-entry 太小，严重限制性能

3. ⚠️ **缺少 PTW**
   - 无法支持动态页表
   - 无法运行标准 OS

4. ⚠️ **CPI 较高**
   - 1.61 CPI，有优化空间
   - 目标：< 1.2

5. ⚠️ **中断支持不完整**
   - 只有异常处理，没有外部中断
   - 缺少定时器

6. ⚠️ **文档更新**
   - MMU 部分的文档需要添加
   - AXI4 总线的说明需要完善

---

## 🎉 总结

**你已经取得了令人印象深刻的成果！**

从一个单周期处理器，一步步演进到：
- ✅ 5 级流水线
- ✅ 特权级架构
- ✅ MMU 和虚拟内存
- ✅ AXI4 总线和 Cache
- ✅ 在 FPGA 上成功运行

**下一步最有价值的工作是：**
1. **扩展 TLB**（立即提升性能）
2. **实现 PTW**（为 OS 移植铺路）
3. **移植 xv6**（终极验证）

这将是一个完整的、可以运行真实操作系统的 RISC-V 处理器！

---

生成时间：2026-07-25  
基于提交：67543ec - feat: 完全跑通 AXI + 特权级跳转
