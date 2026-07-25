from struct import pack

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

# CSRR rd, csr => CSRRS rd, csr, x0 => I-type: opcode=1110011(0x73), funct3=010, rs1=0, imm=csr
def CSRR(rd, csr):
    return I(0x73, rd, 2, 0, csr)

prog = [
    I(0x13, 2, 0, 0, 100),       # addi x2, x0, 100
    I(0x13, 3, 0, 0, 0),         # addi x3, x0, 0
    CSRR(4, 0xB00),              # csrr x4, 0xB00 (mcycle)
    CSRR(5, 0xB02),              # csrr x5, 0xB02 (minstret)
    # loop: 
    I(0x13, 3, 0, 3, 1),         # addi x3, x3, 1
    R(0x33, 3, 0, 3, 3, 1),      # mul x3, x3, x3 (RV32M MUL: funct7=1, funct3=0)
    I(0x13, 2, 0, 2, -1),        # addi x2, x2, -1
    B(0x63, 1, 2, 0, -12),       # bne x2, x0, loop (loop is -12 bytes back)
    # end loop
    CSRR(6, 0xB00),              # csrr x6, 0xB00 (mcycle)
    CSRR(7, 0xB02),              # csrr x7, 0xB02 (minstret)
    R(0x33, 8, 0, 6, 4, 0x20),   # sub x8, x6, x4 (cycles taken)
    R(0x33, 9, 0, 7, 5, 0x20),   # sub x9, x7, x5 (insts executed)
    U(0x37, 10, 0x00001),        # lui x10, 1 => 0x00001000
    S(0x23, 2, 10, 8, 0),        # sw x8, 0(x10)
    S(0x23, 2, 10, 9, 4),        # sw x9, 4(x10)
    S(0x23, 2, 10, 3, 8),        # sw x3, 8(x10)
    J(0x6f, 0, 0),               # j 0
]

for i, inst in enumerate(prog):
    print(f"soc.main_memory.mem[{i}] = 32'h{inst & 0xFFFFFFFF:08X};")
