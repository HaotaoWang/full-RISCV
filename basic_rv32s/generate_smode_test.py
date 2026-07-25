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

def CSRRW(rd, csr, rs1):
    return (csr << 20) | (rs1 << 15) | (1 << 12) | (rd << 7) | 0x73

prog = [
    # ---- M-Mode Initialization (Starts at 0x0) ----
    
    # 0: Delegate ECALL from S-Mode (Cause 9) to S-Mode
    # 1 << 9 = 0x200
    I(0x13, 5, 0, 0, 0x200),    # addi x5, x0, 0x200
    CSRRW(0, 0x302, 5),         # csrw medeleg, x5

    # 8: Set mstatus.MPP = 01 (S-Mode). MPP is bits 12:11. 1 << 11 = 0x800
    I(0x13, 5, 0, 0, 0x800),    # addi x5, x0, 0x800
    CSRRW(0, 0x300, 5),         # csrw mstatus, x5

    # 16: Set mepc to S-Mode entry point (Address 28 = 0x1C)
    I(0x13, 5, 0, 0, 0x1C),     # addi x5, x0, 28
    CSRRW(0, 0x341, 5),         # csrw mepc, x5

    # 24: Return to S-Mode
    0x30200073,                 # mret


    # ---- S-Mode Entry Point (Address 0x1C = 28) ----
    
    # 28: Set stvec to S-Mode handler (Address 44 = 0x2C)
    I(0x13, 5, 0, 0, 0x2C),     # addi x5, x0, 44
    CSRRW(0, 0x105, 5),         # csrw stvec, x5

    # 36: Trigger ECALL! (Should trap to stvec in S-Mode)
    0x00000073,                 # ecall

    # 40: Infinite loop (If trap fails and falls through)
    J(0x6f, 0, 0),              # j 0


    # ---- S-Mode Trap Handler (Address 0x2C = 44) ----
    
    # 44: Write to LED to indicate success! (x3 = 0x10020000)
    U(0x37, 3, 0x10020),        # lui x3, 0x10020
    # 48: Load 0xF (4 LEDs on)
    I(0x13, 2, 0, 0, 0xF),      # addi x2, x0, 0xF
    # 52: Write to MMIO
    S(0x23, 2, 3, 2, 0),        # sw x2, 0(x3)

    # 56: Infinite loop (Success)
    J(0x6f, 0, 0),              # j 0
]

with open("smode_test.hex", "w") as f:
    for inst in prog:
        f.write(f"{inst & 0xFFFFFFFF:08X}\n")

print("Generated smode_test.hex successfully!")
