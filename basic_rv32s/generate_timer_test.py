"""
定时器中断裸机测试程序 (M-Mode)
目标：验证 CLINT 模块与 CPU 的 Timer Interrupt 中断机制
完全不涉及汇编器，手动拼接机器码。
"""

def I(opcode, rd, funct3, rs1, imm):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def S(opcode, funct3, rs1, rs2, imm):
    imm4_0 = imm & 0x1F
    imm11_5 = (imm >> 5) & 0x7F
    return (imm11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm4_0 << 7) | opcode

def U(opcode, rd, imm):
    return ((imm & 0xFFFFF) << 12) | (rd << 7) | opcode

def J(opcode, rd, imm):
    imm20 = (imm >> 20) & 0x1
    imm10_1 = (imm >> 1) & 0x3FF
    imm11 = (imm >> 11) & 0x1
    imm19_12 = (imm >> 12) & 0xFF
    return (imm20 << 31) | (imm19_12 << 12) | (imm11 << 20) | (imm10_1 << 21) | (rd << 7) | opcode
    
def R(opcode, funct3, funct7, rd, rs1, rs2):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def CSR(funct3, rd, rs1, csr):
    return ((csr & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | 0x73

def CSRW(csr, rs1):
    return CSR(1, 0, rs1, csr) # CSRRW x0, csr, rs1

def CSRS(csr, rs1):
    return CSR(2, 0, rs1, csr) # CSRRS x0, csr, rs1

def MRET():
    return 0x30200073

# 寄存器别名
x0 = 0
ra = 1
sp = 2
gp = 3
tp = 4
t0 = 5
t1 = 6
t2 = 7
s0 = 8
s1 = 9
a0 = 10
a1 = 11
x3 = 3
t3 = 28

prog = [
    # 0x00: 设置 mtvec 到异常处理入口 (假设偏移为 0x2C)
    U(0x37, t0, 0),             # lui t0, 0
    I(0x13, t0, 0, t0, 0x2C),   # addi t0, t0, 0x2C (trap_handler 的绝对地址)
    CSRW(0x305, t0),            # csrw mtvec, t0

    # 0x0C: 读取 mtime (0x0200BFF8)
    U(0x37, t1, 0x0200B),       # lui t1, 0x0200B (0x0200B000)
    I(0x03, t2, 2, t1, 0xFF8),  # lw t2, -8(t1)  注意: 0xFF8 是负数吗？
    # 纠正：0xFF8 在 12bit signed 中是 -8。基地址为 0x0200C000 时，-8 为 0x0200BFF8！
    # 所以我们用 lui t1, 0x0200C
]

prog = [
    # 0x00: 设置 mtvec 到 0x28 (Trap Handler 入口)
    U(0x37, t0, 0),             # lui t0, 0
    I(0x13, t0, 0, t0, 0x2C),   # addi t0, t0, 0x2C (即 44)
    CSRW(0x305, t0),            # csrw mtvec, t0

    # 0x0C: 读取 mtime (0x0200BFF8)
    # 0x0200C000 - 8 = 0x0200BFF8
    U(0x37, t1, 0x0200C),       # lui t1, 0x0200C
    I(0x03, t2, 2, t1, -8 & 0xFFF), # lw t2, -8(t1) 
    
    # 0x14: 加上延时 delay = 50 周期
    I(0x13, t3, 0, x0, 50),     # addi t3, x0, 50
    R(0x33, 0, 0, t2, t2, t3),  # add t2, t2, t3
    
    # 0x20: 写入 mtimecmp (0x02004000)
    U(0x37, t1, 0x02004),       # lui t1, 0x02004
    S(0x23, 2, t1, t2, 0),      # sw t2, 0(t1)  (mtimecmp low)
    S(0x23, 2, t1, x0, 4),      # sw x0, 4(t1)  (mtimecmp high)

    # 0x2C: 开启 mie.MTIE (位 7, 值 0x80)
    I(0x13, t0, 0, x0, 0x80),   # addi t0, x0, 0x80
    CSRS(0x304, t0),            # csrs mie, t0

    # 0x34: 开启 mstatus.MIE (位 3, 值 0x8)
    I(0x13, t0, 0, x0, 0x08),   # addi t0, x0, 8
    CSRS(0x300, t0),            # csrs mstatus, t0

    # 0x3C: 死循环等待中断 loop:
    J(0x6f, x0, 0),             # j loop

    # ========================== TRAP HANDLER ==========================
    # 0x40 (偏移量不准，我们要重新计算绝对偏移！其实只需把指令写进去数一下)
]

# 重新精确定位汇编:
insts = []

# 0x00: mtvec setup -> 指向 0x38
insts.append(U(0x37, t0, 0))              # 0x00: lui t0, 0
insts.append(I(0x13, t0, 0, t0, 0x38))    # 0x04: addi t0, t0, 0x38
insts.append(CSRW(0x305, t0))             # 0x08: csrw mtvec, t0

# 读取 mtime
insts.append(U(0x37, t1, 0x0200C))        # 0x0C: lui t1, 0x0200C
insts.append(I(0x03, t2, 2, t1, -8 & 0xFFF)) # 0x10: lw t2, -8(t1) (0x0200BFF8)

# mtime + 50
insts.append(I(0x13, t3, 0, x0, 50))      # 0x14: addi t3, x0, 50
insts.append(R(0x33, 0, 0, t2, t2, t3))   # 0x18: add t2, t2, t3

# 写 mtimecmp
insts.append(U(0x37, t1, 0x02004))        # 0x1C: lui t1, 0x02004
insts.append(S(0x23, 2, t1, t2, 0))       # 0x20: sw t2, 0(t1)
insts.append(S(0x23, 2, t1, x0, 4))       # 0x24: sw x0, 4(t1)

# 开启中断
insts.append(I(0x13, t0, 0, x0, 0x88))    # 0x28: addi t0, x0, 0x88 (MTIE=0x80 | MIE=0x08)
# 分两次写确保不出错
insts.append(CSRS(0x304, t0))             # 0x2C: csrs mie, t0 (设置MTIE)
insts.append(CSRS(0x300, t0))             # 0x30: csrs mstatus, t0 (设置MIE)

# 死循环 
# 0x34
insts.append(J(0x6f, x0, 0))              # 0x34: j 0x34

# ==================== Trap Handler (0x38) =========================
# 将 x3 加 1, 方便在仿真里看到 x3 的值变化！
insts.append(I(0x13, x3, 0, x3, 1))       # 0x38: addi x3, x3, 1

# 重置 mtimecmp (mtimecmp += 50)
insts.append(U(0x37, t1, 0x02004))        # 0x3C: lui t1, 0x02004
insts.append(I(0x03, t2, 2, t1, 0))       # 0x40: lw t2, 0(t1)
insts.append(I(0x13, t3, 0, x0, 50))      # 0x44: addi t3, x0, 50
insts.append(R(0x33, 0, 0, t2, t2, t3))   # 0x48: add t2, t2, t3
insts.append(S(0x23, 2, t1, t2, 0))       # 0x4C: sw t2, 0(t1)

insts.append(MRET())                      # 0x50: mret

with open("timer_test.hex", "w") as f:
    for inst in insts:
        f.write(f"{inst & 0xFFFFFFFF:08X}\n")

print("Generated timer_test.hex successfully!")
