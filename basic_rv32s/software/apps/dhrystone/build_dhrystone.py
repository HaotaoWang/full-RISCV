#!/usr/bin/env python3
"""Build the reproducible board Dhrystone ELF and retained HEX image."""

from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path


APP = Path(__file__).resolve().parent
SOFTWARE = APP.parents[1]
ROOT = SOFTWARE.parent
RUNTIME = SOFTWARE / "runtime"
DEFAULT_OUT = SOFTWARE / "build" / "dhrystone"


def tool(name: str, fallback: str) -> str:
    found = shutil.which(name)
    if found:
        return found
    if Path(fallback).exists():
        return fallback
    raise SystemExit(f"Required tool not found: {name}")


GCC = tool("riscv-none-elf-gcc", r"D:\riscv_gcc\bin\riscv-none-elf-gcc.exe")
OBJCOPY = tool("riscv-none-elf-objcopy", r"D:\riscv_gcc\bin\riscv-none-elf-objcopy.exe")


def execute(command: list[str]) -> None:
    result = subprocess.run(command, cwd=ROOT, text=True, errors="replace")
    if result.returncode:
        raise SystemExit(result.returncode)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runs", type=int, default=100000,
                        help="benchmark iterations (default: 100000)")
    parser.add_argument("--cpu-hz", type=int, default=50000000,
                        help="CPU frequency used for the report (default: 50 MHz)")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    if args.runs <= 0 or args.cpu_hz <= 0:
        parser.error("--runs and --cpu-hz must be positive")

    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    sources = [APP / "dhrystone.c", APP / "dhrystone_main.c",
               RUNTIME / "syscalls.c", RUNTIME / "crt0.S"]
    common = [
        GCC, "-march=rv32i_zicsr_zifencei", "-mabi=ilp32", "-O2",
        "-nostdlib", "-nostartfiles", "-ffreestanding", "-std=gnu89",
        "-fwrapv", "-Wno-implicit-int", "-Wno-implicit-function-declaration",
        f"-I{APP}", f"-I{RUNTIME}", f"-DNUMBER_OF_RUNS={args.runs}",
        f"-DRISCV_CPU_HZ={args.cpu_hz}", "-DDHRY_FIXED_RUNS=1",
    ]
    objects: list[Path] = []
    for source in sources:
        obj = output / f"{source.stem}.o"
        objects.append(obj)
        execute([*common, "-c", str(source), "-o", str(obj)])

    elf = output / "dhrystone.elf"
    hex_file = output / "dhrystone.hex"
    execute([*common, "-T", str(RUNTIME / "linker.ld"),
             *(str(obj) for obj in objects), "-lgcc", "-o", str(elf)])
    execute([OBJCOPY, "-O", "verilog", "--verilog-data-width", "4",
             str(elf), str(hex_file)])
    print(f"Built {elf}")
    print(f"Built {hex_file}")
    print(f"Configuration: rv32i_zicsr_zifencei/ilp32 -O2, runs={args.runs}, cpu_hz={args.cpu_hz}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
