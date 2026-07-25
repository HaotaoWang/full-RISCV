import struct

def R(opcode, rd, funct3, rs1, rs2, funct7):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def I(opcode, rd, funct3, rs1, imm):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def S(opcode, funct3, rs1, rs2, imm):
    imm4_0 = imm & 0x1F
    imm11_5 = (imm >> 5) & 0x7F
    return (imm11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm4_0 << 7) | opcode

def B(opcode, funct3, rs1, rs2, imm):
    imm12 = (imm >> 12) & 0x1
    imm10_5 = (imm >> 5) & 0x3F
    imm4_1 = (imm >> 1) & 0xF
    imm11 = (imm >> 11) & 0x1
    return (imm12 << 31) | (imm10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm4_1 << 8) | (imm11 << 7) | opcode

def U(opcode, rd, imm):
    return ((imm & 0xFFFFF) << 12) | (rd << 7) | opcode

def J(opcode, rd, imm):
    imm20 = (imm >> 20) & 0x1
    imm10_1 = (imm >> 1) & 0x3FF
    imm11 = (imm >> 11) & 0x1
    imm19_12 = (imm >> 12) & 0xFF
    return (imm20 << 31) | (imm19_12 << 12) | (imm11 << 20) | (imm10_1 << 21) | (rd << 7) | opcode

prog = [
    # 初始化
    I(0x13, 2, 0, 0, 0),         # 0: addi x2, x0, 0       (LED counter)
    U(0x37, 3, 0x10020),         # 4: lui x3, 0x10020      (x3 = 0x10020000, LED MMIO address)
    I(0x13, 0, 0, 0, 0),         # 8: NOP (保持指令对齐，使得下面的跳转地址不变)
    
    # 外部大循环起点 (Address: 12)
    # 写入 LED
    S(0x23, 2, 3, 2, 0),         # sw x2, 0(x3)         (Write counter to LED)
    
    # 准备延时常数
    U(0x37, 4, 0x00400),         # lui x4, 0x00400      (x4 = 0x00400000 = 4,194,304次循环)
                                 # (在 50MHz 时钟下，大概延时 0.2 ~ 0.3 秒)
    
    # 延时内部小循环起点 (Address: 20)
    I(0x13, 4, 0, 4, -1),        # addi x4, x4, -1      (递减)
    B(0x63, 1, 4, 0, -4),        # bne x4, x0, -4       (如果不是0，跳回 addi 继续减)
    
    # 小循环结束，LED counter 增加
    I(0x13, 2, 0, 2, 1),         # addi x2, x2, 1
    
    # 跳回大循环起点
    J(0x6f, 0, -20),             # j -20                (跳回 sw x2, 0(x3))
]

with open("led_test_axi.hex", "w") as f:
    for inst in prog:
        f.write(f"{inst & 0xFFFFFFFF:08X}\n")

print("Generated led_test_axi.hex successfully!")
