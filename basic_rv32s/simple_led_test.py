#!/usr/bin/env python3
"""
简化的 LED 测试程序 - 用于验证 MMIO 写入是否正常工作
不使用 MMU，直接在 M-Mode 使用物理地址
"""

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

prog = [
    # 简单的 M-Mode LED 测试（无 MMU）
    # LED MMIO 物理地址: 0x10020000

    # 0: 加载 LED 地址到 x3
    U(0x37, 3, 0x10020),        # lui x3, 0x10020  -> x3 = 0x10020000

    # 4: 加载 LED 数据 (0xF = 4 个 LED 全亮)
    I(0x13, 2, 0, 0, 0xF),      # addi x2, x0, 0xF -> x2 = 0x0000000F

    # 8: 写入 LED
    S(0x23, 2, 3, 2, 0),        # sw x2, 0(x3)     -> [0x10020000] = 0xF

    # 12: 无限循环（成功）
    J(0x6f, 0, 0),              # j 0 (跳转到自己)
]

import os

# 写入根目录
with open("simple_led_test.hex", "w") as f:
    for inst in prog:
        f.write(f"{inst & 0xFFFFFFFF:08X}\n")

# 写入 FPGA 目录
vivado_path = os.path.join("fpga", "My_Kintex7_RV32_SoC", "simple_led_test.hex")
try:
    with open(vivado_path, "w") as f:
        for inst in prog:
            f.write(f"{inst & 0xFFFFFFFF:08X}\n")
    print(f"[OK] Generated simple_led_test.hex successfully!")
    print(f"   - Root: simple_led_test.hex")
    print(f"   - FPGA: {vivado_path}")
    print()
    print("[INFO] Instructions:")
    print("   1. Modify FPGA_Top.v line 66 to use this test:")
    print('      .INIT_FILE("simple_led_test.hex")')
    print("   2. Rebuild and program the FPGA")
    print("   3. LED should light up IMMEDIATELY (not 20 seconds)")
    print()
    print("Expected behavior:")
    print("   - If LED lights up instantly: Cache fix works!")
    print("   - If LED still takes 20s: Other issue exists")
except Exception as e:
    print(f"[ERROR] Failed to write to Vivado directory: {e}")
