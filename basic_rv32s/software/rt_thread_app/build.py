import os
import glob
import subprocess

CC = "D:/riscv_gcc/bin/riscv-none-elf-gcc"
OBJCOPY = "D:/riscv_gcc/bin/riscv-none-elf-objcopy"

CFLAGS = ["-march=rv32im_zicsr", "-mabi=ilp32", "-O2", "-ffunction-sections", "-fdata-sections", "-I./include", "-I."]
LDFLAGS = ["-T", "link.lds", "-nostartfiles", "-Wl,--gc-sections", "-lc", "-lm", "-lgcc"]

c_sources = glob.glob("src/*.c") + ["board.c", "libcpu/cpuport.c", "main.c"]
asm_sources = ["libcpu/context_gcc.S", "startup.S"]

objs = []

def run_cmd(cmd):
    print(" ".join(cmd))
    res = subprocess.run(cmd)
    if res.returncode != 0:
        print(f"Error compiling! Exit code {res.returncode}")
        exit(1)

# Compile C files
for src in c_sources:
    obj = src.replace(".c", ".o")
    objs.append(obj)
    run_cmd([CC] + CFLAGS + ["-c", src, "-o", obj])

# Compile ASM files
for src in asm_sources:
    obj = src.replace(".S", ".o")
    objs.append(obj)
    run_cmd([CC] + CFLAGS + ["-c", src, "-o", obj])

# Link
print("Linking rtthread.elf...")
run_cmd([CC] + CFLAGS + LDFLAGS + ["-o", "rtthread.elf"] + objs)

# Objcopy
print("Generating rtthread.bin...")
run_cmd([OBJCOPY, "-O", "binary", "rtthread.elf", "rtthread.bin"])

# Makehex
print("Generating rtthread.hex...")
run_cmd(["python", "makehex.py", "rtthread.bin", "rtthread.hex"])

print("Build successful! Copying to SoC root directory...")
run_cmd(["powershell", "-Command", "Copy-Item rtthread.hex -Destination ..\\..\\rtthread.hex -Force"])

print("All done!")
