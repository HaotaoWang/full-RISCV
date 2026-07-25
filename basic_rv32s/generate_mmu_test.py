import struct

def R(opcode, rd, funct3, rs1, rs2, funct7):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def I(opcode, rd, funct3, rs1, imm):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def S(opcode, funct3, rs1, rs2, imm):
    imm4_0 = imm & 0x1F
    imm11_5 = (imm >> 5) & 0x7F
    return (imm11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm4_0 << 7) | opcode

def J(opcode, rd, imm):
    imm20 = (imm >> 20) & 0x1
    imm10_1 = (imm >> 1) & 0x3FF
    imm11 = (imm >> 11) & 0x1
    imm19_12 = (imm >> 12) & 0xFF
    return (imm20 << 31) | (imm19_12 << 12) | (imm11 << 20) | (imm10_1 << 21) | (rd << 7) | opcode

def U(opcode, rd, imm):
    return ((imm & 0xFFFFF) << 12) | (rd << 7) | opcode

def CSRRW(rd, csr, rs1):
    return (csr << 20) | (rs1 << 15) | (1 << 12) | (rd << 7) | 0x73

prog = [
    # ---- M-Mode Initialization (Starts at 0x0) ----

    # 0: Set ITLB Entry (VA: 0x4000_0000 -> PA: 0x0000_0000)
    # tlb_wvpn = 0x40000
    U(0x37, 5, 0x40),           # lui x5, 0x40 (x5 = 0x40000)
    CSRRW(0, 0x803, 5),         # csrw 0x803 (tlb_wvpn), x5
    
    # 8: itlb_wpte = PPN=0 | Flags (V=1,R=1,W=1,X=1,U=0) = 0x0F
    I(0x13, 5, 0, 0, 0x0F),     # addi x5, x0, 0x0F
    CSRRW(0, 0x804, 5),         # csrw 0x804 (itlb_we), x5

    # 16: Set DTLB Entry (VA: 0x8000_0000 -> PA: 0x1002_0000)
    # tlb_wvpn = 0x80000
    U(0x37, 5, 0x80),           # lui x5, 0x80 (x5 = 0x80000)
    CSRRW(0, 0x803, 5),         # csrw 0x803 (tlb_wvpn), x5
    
    # 24: dtlb_wpte = PPN << 10 | flags
    # PA = 0x1002_0000, PPN = PA>>12 = 0x10020
    # PTE = 0x10020 << 10 | 0x07 = 0x04008007
    # lui x5, 0x4008  -> x5 = 0x4008<<12 = 0x04008000
    U(0x37, 5, 0x4008),         # lui x5, 0x4008 -> x5=0x04008000
    I(0x13, 5, 0, 5, 0x07),     # addi x5, x5, 0x07 -> x5=0x04008007
    CSRRW(0, 0x805, 5),         # csrw 0x805 (dtlb_we), x5

    # 36: Set mstatus.MPP = 01 (S-Mode). MPP is bits 12:11. 1 << 11 = 0x800
    U(0x37, 5, 1),              # lui x5, 1 -> x5 = 0x0000_1000
    I(0x13, 5, 0, 5, 0x800),    # addi x5, x5, -2048 (0x800) -> x5 = 0x0000_0800
    CSRRW(0, 0x300, 5),         # csrw mstatus, x5

    # 48: Set mepc to S-Mode entry point (Virtual Address!)
    # S-Mode entry 'lui x3' is at physical addr 0x54 (84)
    # ITLB maps VA 0x4000_0000 -> PA 0x0, so VA = 0x4000_0054
    U(0x37, 5, 0x40000),        # lui x5, 0x40000 -> x5=0x4000_0000
    I(0x13, 5, 0, 5, 0x54),     # addi x5, x5, 0x54 -> x5=0x4000_0054
    CSRRW(0, 0x341, 5),         # csrw mepc, x5

    # 60: Enable MMU (satp.MODE = 1)
    # satp = 1 << 31 = 0x8000_0000
    U(0x37, 5, 0x80000),        # lui x5, 0x80000
    CSRRW(0, 0x180, 5),         # csrw satp, x5

    # 68: NOPs to wait for CSR write to commit in WB stage before MRET
    0x00000013,                 # nop
    0x00000013,                 # nop
    0x00000013,                 # nop

    # 80: Return to S-Mode (Jump to 0x4000_0054)
    0x30200073,                 # mret

    # ---- S-Mode Entry Point (Physical 0x54=84, Virtual 0x4000_0054) ----
    # lua x3: this is addr 84 = 0x54 in physical memory
    # LED VA is 0x8000_0000
    U(0x37, 3, 0x80000),        # lui x3, 0x80000
    # 80: Load 0xF (4 LEDs on)
    I(0x13, 2, 0, 0, 0xF),      # addi x2, x0, 0xF
    # 84: Write to MMIO using Virtual Address
    S(0x23, 2, 3, 2, 0),        # sw x2, 0(x3)

    # 88: Infinite loop (Success)
    J(0x6f, 0, 0),              # j 0
]

import os

with open("mmu_test.hex", "w") as f:
    for inst in prog:
        f.write(f"{inst & 0xFFFFFFFF:08X}\n")

vivado_path = os.path.join("fpga", "My_Kintex7_RV32_SoC", "mmu_test.hex")
try:
    with open(vivado_path, "w") as f:
        for inst in prog:
            f.write(f"{inst & 0xFFFFFFFF:08X}\n")
    print(f"Generated mmu_test.hex successfully at root and {vivado_path}!")
except Exception as e:
    print(f"Generated mmu_test.hex at root, but failed to write to Vivado directory: {e}")
