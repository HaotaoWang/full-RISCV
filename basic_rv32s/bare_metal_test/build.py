import os
import subprocess

CC = "D:/riscv_gcc/bin/riscv-none-elf-gcc"
OBJCOPY = "D:/riscv_gcc/bin/riscv-none-elf-objcopy"

CFLAGS = ["-march=rv32im_zicsr", "-mabi=ilp32", "-O2", "-ffunction-sections", "-fdata-sections"]
LDFLAGS = ["-T", "link.lds", "-nostartfiles", "-Wl,--gc-sections", "-lc", "-lm", "-lgcc"]

def run_cmd(cmd):
    print(" ".join(cmd))
    res = subprocess.run(cmd)
    if res.returncode != 0:
        print(f"Error compiling! Exit code {res.returncode}")
        exit(1)

run_cmd([CC] + CFLAGS + ["-c", "startup.S", "-o", "startup.o"])
run_cmd([CC] + CFLAGS + ["-c", "main.c", "-o", "main.o"])
run_cmd([CC] + CFLAGS + LDFLAGS + ["-o", "program.elf", "startup.o", "main.o"])
run_cmd([OBJCOPY, "-O", "binary", "program.elf", "program.bin"])
run_cmd(["python", "../software/rt_thread_app/makehex.py", "program.bin", "program.hex"])
run_cmd(["powershell", "-Command", "Copy-Item program.hex -Destination ..\\bare_metal.hex -Force"])
print("Built bare_metal.hex!")
