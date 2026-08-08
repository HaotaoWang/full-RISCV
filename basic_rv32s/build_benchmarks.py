import os
import subprocess
import sys

def run_cmd(cmd, cwd='.'):
    print(f"Running in {cwd}:\n  {cmd}\n")
    ret = subprocess.call(cmd, shell=True, cwd=cwd)
    if ret != 0:
        print(f"Command failed with exit code {ret}")
        sys.exit(ret)

def main():
    print("Building CoreMark and Dhrystone for basic_rv32s...\n")
    
    # Toolchain configuration (Absolute path to xPack RISC-V GCC)
    cc = r"D:\riscv_gcc\bin\riscv-none-elf-gcc.exe"
    objcopy = r"D:\riscv_gcc\bin\riscv-none-elf-objcopy.exe"
    
    # Use RV32I instead of RV32IM because basic_rv32s does not have a hardware divider.
    # The compiler will use libgcc for both soft-multiply and soft-divide.
    arch = "rv32i_zicsr_zifencei"
    abi = "ilp32"
    
    os.makedirs("software/build/coremark", exist_ok=True)
    os.makedirs("software/build/dhrystone", exist_ok=True)
    
    # =========================================================================
    # 1. Build CoreMark
    # =========================================================================
    print("--- Building CoreMark ---")
    coremark_srcs = [
        "../../coremark/core_main.c",
        "../../coremark/core_list_join.c",
        "../../coremark/core_matrix.c",
        "../../coremark/core_state.c",
        "../../coremark/core_util.c",
        "core_portme.c",
        "../../../runtime/crt0.S",
        "../../../runtime/syscalls.c"
    ]
    
    coremark_flags = f"-march={arch} -mabi={abi} -O2 -nostdlib -nostartfiles -ffreestanding " \
                     f"-I. -I../../coremark -I../../../runtime " \
                     f"-DPERFORMANCE_RUN=1 -DITERATIONS=3000 " \
                     f"-T ../../../runtime/linker.ld"
                     
    cmd_coremark_elf = f"{cc} {coremark_flags} {' '.join(coremark_srcs)} -lgcc -o ../../../build/coremark/coremark.elf"
    run_cmd(cmd_coremark_elf, cwd="software/apps/wrappers/coremark")
    
    cmd_coremark_hex = f"{objcopy} -O verilog --verilog-data-width 4 ../../../build/coremark/coremark.elf ../../../build/coremark/coremark.hex"
    run_cmd(cmd_coremark_hex, cwd="software/apps/wrappers/coremark")
    
    # =========================================================================
    # 2. Build Dhrystone
    # =========================================================================
    print("--- Building Dhrystone ---")
    dhrystone_srcs = [
        "dhrystone.c",
        "dhrystone_main.c",
        "../../runtime/crt0.S",
        "../../runtime/syscalls.c"
    ]
    
    dhrystone_flags = f"-march={arch} -mabi={abi} -O2 -nostdlib -nostartfiles -ffreestanding " \
                      f"-I. -I../../runtime -std=gnu89 -fwrapv -Wno-implicit-int -Wno-implicit-function-declaration " \
                      f"-T ../../runtime/linker.ld"
                      
    cmd_dhrystone_elf = f"{cc} {dhrystone_flags} {' '.join(dhrystone_srcs)} -lgcc -o ../../build/dhrystone/dhrystone.elf"
    run_cmd(cmd_dhrystone_elf, cwd="software/apps/dhrystone")
    
    cmd_dhrystone_hex = f"{objcopy} -O verilog --verilog-data-width 4 ../../build/dhrystone/dhrystone.elf ../../build/dhrystone/dhrystone.hex"
    run_cmd(cmd_dhrystone_hex, cwd="software/apps/dhrystone")
    
    print("==========================================================")
    print("Build completed successfully!")
    print("Hex files are located at:")
    print("  - software/build/coremark/coremark.hex")
    print("  - software/build/dhrystone/dhrystone.hex")
    print("==========================================================\n")

if __name__ == "__main__":
    main()
