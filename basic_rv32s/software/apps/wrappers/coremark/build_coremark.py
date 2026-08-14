#!/usr/bin/env python3
"""Build the reproducible basic_rv32s CoreMark board image."""

from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path


PORT = Path(__file__).resolve().parent
SOFTWARE = PORT.parents[2]
ROOT = SOFTWARE.parent
COREMARK = SOFTWARE / "apps" / "coremark"
RUNTIME = SOFTWARE / "runtime"
DEFAULT_OUT = SOFTWARE / "build" / "coremark"


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
    parser.add_argument("--iterations", type=int, default=3000)
    parser.add_argument("--cpu-hz", type=int, default=50000000)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    if args.iterations <= 0 or args.cpu_hz <= 0:
        parser.error("--iterations and --cpu-hz must be positive")

    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    sources = [COREMARK / name for name in (
        "core_main.c", "core_list_join.c", "core_matrix.c",
        "core_state.c", "core_util.c",
    )] + [PORT / "core_portme.c", RUNTIME / "syscalls.c", RUNTIME / "crt0.S"]
    common = [
        GCC, "-march=rv32im_zicsr_zifencei", "-mabi=ilp32", "-O2",
        "-nostdlib", "-nostartfiles", "-ffreestanding",
        f"-I{PORT}", f"-I{COREMARK}", f"-I{RUNTIME}",
        "-DPERFORMANCE_RUN=1", f"-DITERATIONS={args.iterations}",
        f"-DCOREMARK_CPU_HZ={args.cpu_hz}ULL",
    ]
    objects: list[Path] = []
    for source in sources:
        obj = output / f"{source.stem}.o"
        objects.append(obj)
        execute([*common, "-c", str(source), "-o", str(obj)])

    elf = output / "coremark.elf"
    hex_file = output / "coremark.hex"
    execute([*common, "-T", str(RUNTIME / "linker.ld"),
             *(str(obj) for obj in objects), "-lgcc", "-o", str(elf)])
    execute([OBJCOPY, "-O", "verilog", "--verilog-data-width", "4",
             str(elf), str(hex_file)])
    print(f"Built {elf}")
    print(f"Built {hex_file}")
    print("Configuration: rv32im_zicsr_zifencei/ilp32 -O2, "
          f"iterations={args.iterations}, cpu_hz={args.cpu_hz}, static 2K")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
