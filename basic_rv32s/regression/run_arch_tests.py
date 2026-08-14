#!/usr/bin/env python3
"""Build and run the ACT4 RV32I bootstrap set on the RTL DUT.

Without a Sail-generated reference signature these runs intentionally report
SIGRUN, not PASS.  The same runner accepts ACT4 self-checking ELF files later;
those produce authoritative PASSED/FAILED results.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARCH_ROOT = ROOT / "software" / "apps" / "riscv-arch-tests"
ENV = ARCH_ROOT / "tests" / "env"
I_TESTS = ARCH_ROOT / "tests" / "rv32i" / "I"
PORT = ROOT / "software" / "apps" / "wrappers" / "riscv_arch"
OUT = ROOT / "regression" / "out" / "arch_tests"
TB = ROOT / "regression" / "tb" / "arch_test_tb.v"

BOOTSTRAP = ("I-nop-00", "I-lui-00", "I-auipc-00", "I-addi-00", "I-add-00")
SUMMARY_RE = re.compile(r'RVCP-SUMMARY: TEST (PASSED|FAILED|SIGRUN) - Test File "([^"]+)"')


def tool(name: str, fallback: str) -> str:
    found = shutil.which(name)
    if found:
        return found
    if Path(fallback).exists():
        return fallback
    raise RuntimeError(f"required tool not found: {name}")


GCC = tool("riscv-none-elf-gcc", r"D:\riscv_gcc\bin\riscv-none-elf-gcc.exe")
OBJCOPY = tool("riscv-none-elf-objcopy", r"D:\riscv_gcc\bin\riscv-none-elf-objcopy.exe")
NM = tool("riscv-none-elf-nm", r"D:\riscv_gcc\bin\riscv-none-elf-nm.exe")
IVERILOG = tool("iverilog", r"D:\iverilog\bin\iverilog.exe")
VVP = tool("vvp", r"D:\iverilog\bin\vvp.exe")


SOC_SOURCES = tuple(
    [
        ROOT / "RV32_SoC_AXI_Top.v",
        ROOT / "modules" / "RV32I46F_5SP_MMIO.v",
        ROOT / "modules" / "axi_clint.v",
        ROOT / "modules" / "axi_ram_init.v",
    ]
    + sorted((ROOT / "modules" / "cache").glob("*.v"))
    + [
        ROOT.parent / "verilog-axi" / "rtl" / "axi_interconnect.v",
        ROOT.parent / "verilog-axi" / "rtl" / "arbiter.v",
        ROOT.parent / "verilog-axi" / "rtl" / "priority_encoder.v",
        ROOT / "testbenches" / "BUFG.v",
    ]
)


@dataclass
class Result:
    name: str
    status: str
    seconds: float
    detail: str


def run(cmd: list[str], timeout: int = 180) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd, cwd=ROOT, capture_output=True, text=True, errors="replace", timeout=timeout, check=False
    )


def compile_tb() -> Path:
    vvp = OUT / "arch_test_tb.vvp"
    cmd = [IVERILOG, "-g2012", "-s", "arch_test_tb", "-I", str(ROOT), "-I", str(ROOT / "modules"),
           "-o", str(vvp), str(TB), *(str(path) for path in SOC_SOURCES)]
    result = run(cmd)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return vvp


def build_signature_elf(name: str) -> tuple[Path, Path, int]:
    source = I_TESTS / f"{name}.S"
    if not source.exists():
        raise FileNotFoundError(source)
    elf = OUT / f"{name}.sig.elf"
    binary = OUT / f"{name}.sig.bin"
    hex_file = OUT / f"{name}.sig.hex"
    compile_cmd = [
        GCC, "-o", str(elf), "-march=rv32i_zicsr", "-mabi=ilp32", "-DSIGNATURE", "-DXLEN=32",
        "-DTEST_FLEN=0", f"-I{PORT}", f"-I{ENV}", f"-T{PORT / 'link.ld'}", "-O0", "-g",
        "-mcmodel=medany", "-nostdlib", "-Wl,--no-warn-rwx-segments", str(source),
    ]
    result = run(compile_cmd)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    result = run([OBJCOPY, "-O", "binary", str(elf), str(binary)])
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    data = binary.read_bytes()
    if len(data) > 262144:
        raise RuntimeError(f"{name}: image is {len(data)} bytes, exceeds 256 KiB architecture-test RAM")
    data += b"\0" * ((4 - len(data) % 4) % 4)
    hex_file.write_text("".join(f"{int.from_bytes(data[i:i+4], 'little'):08X}\n" for i in range(0, len(data), 4)))
    symbols = run([NM, "-n", str(elf)])
    match = re.search(r"^([0-9a-fA-F]+)\s+\w\s+tohost$", symbols.stdout, re.MULTILINE)
    if symbols.returncode or not match:
        raise RuntimeError(f"{name}: unable to locate ACT4 tohost symbol")
    return elf, hex_file, int(match.group(1), 16) // 4


def execute(vvp: Path, name: str, hex_file: Path, tohost_word: int, max_cycles: int) -> Result:
    started = time.monotonic()
    try:
        proc = run([VVP, str(vvp), f"+HEX_FILE={hex_file}", f"+TOHOST_WORD={tohost_word}",
                    f"+MAX_CYCLES={max_cycles}"], timeout=300)
        transcript = proc.stdout + proc.stderr
    except subprocess.TimeoutExpired as exc:
        transcript = (exc.stdout or "") + (exc.stderr or "")
        return Result(name, "TIMEOUT", time.monotonic() - started, transcript[-500:])
    match = SUMMARY_RE.search(transcript)
    if match:
        status = match.group(1)
        detail = match.group(2)
    elif "ARCH_TEST_HTIF: SIGRUN" in transcript and proc.returncode == 0:
        status = "SIGRUN"
        detail = next(line for line in transcript.splitlines() if "ARCH_TEST_HTIF: SIGRUN" in line)
    else:
        status = "RTL_ERROR" if proc.returncode else "NO_SUMMARY"
        detail = transcript[-800:].strip()
    return Result(name, status, time.monotonic() - started, detail)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tests", nargs="*", default=list(BOOTSTRAP), help="test stems, e.g. I-nop-00")
    parser.add_argument("--max-cycles", type=int, default=2_000_000)
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    vvp = compile_tb()
    results: list[Result] = []
    for name in args.tests:
        print(f"[BUILD] {name}", flush=True)
        try:
            _, hex_file, tohost_word = build_signature_elf(name)
            result = execute(vvp, name, hex_file, tohost_word, args.max_cycles)
        except Exception as exc:  # keep the batch running and report every failure
            result = Result(name, "BUILD_ERROR", 0.0, str(exc))
        results.append(result)
        print(f"[{result.status:10}] {name} ({result.seconds:.2f}s) {result.detail}", flush=True)

    counts: dict[str, int] = {}
    for result in results:
        counts[result.status] = counts.get(result.status, 0) + 1
    report = {"mode": "ACT4 signature bootstrap (not certification)", "counts": counts,
              "results": [asdict(result) for result in results]}
    (OUT / "rv32i_bootstrap_summary.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Summary: {counts}")
    print("NOTE: SIGRUN proves the ACT image completed on RTL; only PASSED is an architectural certification result.")
    return 1 if any(r.status not in {"SIGRUN", "PASSED"} for r in results) else 0


if __name__ == "__main__":
    sys.exit(main())
