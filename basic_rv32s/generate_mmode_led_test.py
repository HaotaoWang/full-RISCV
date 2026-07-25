"""
纯 M-Mode 极简点灯测试
目标：验证 MMIO 写 LED 的基础硬件通路是否正常
完全不涉及 S-Mode、ECALL、Trap，排除所有复杂逻辑干扰

执行序列:
  lui  x1, 0x10020     # x1 = 0x10020000 (LED 外设地址)
  addi x2, x0, 0xF    # x2 = 0x0000000F (点亮全部4个LED)
  sw   x2, 0(x1)       # MEM[0x10020000] = 0xF -> 点灯!
  j    0               # 停在此处(死循环)
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

prog = [
    # 地址 0x00: lui x1, 0x10020   -> x1 = 0x10020000
    U(0x37, 1, 0x10020),
    # 地址 0x04: addi x2, x0, 0xF  -> x2 = 15
    I(0x13, 2, 0, 0, 0xF),
    # 地址 0x08: sw x2, 0(x1)      -> 写 LED 寄存器
    S(0x23, 2, 1, 2, 0),  # funct3=2(SW), rs1=1(base), rs2=2(data), imm=0
    # 地址 0x0C: j 0               -> 原地死循环
    J(0x6f, 0, 0),
]

with open("smode_test.hex", "w") as f:
    for inst in prog:
        f.write(f"{inst & 0xFFFFFFFF:08X}\n")

print("Generated smode_test.hex (M-Mode LED test) successfully!")
print("Instructions:")
for i, inst in enumerate(prog):
    print(f"  [{i*4:#010x}]: {inst & 0xFFFFFFFF:08X}")
