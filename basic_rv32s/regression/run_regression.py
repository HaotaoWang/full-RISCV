#!/usr/bin/env python3
"""One-command regression runner for basic_rv32s."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REGRESSION = ROOT / "regression"
OUT = REGRESSION / "out"
FIRMWARE = REGRESSION / "firmware"
TB = REGRESSION / "tb"


def find_tool(name: str, fallback: str) -> str:
    found = shutil.which(name)
    if found:
        return found
    candidate = Path(fallback)
    if candidate.exists():
        return str(candidate)
    raise RuntimeError(f"Required tool not found: {name} (also checked {candidate})")


PYTHON = sys.executable
IVERILOG = find_tool("iverilog", r"D:\iverilog\bin\iverilog.exe")
VVP = find_tool("vvp", r"D:\iverilog\bin\vvp.exe")
GCC = find_tool("riscv-none-elf-gcc", r"D:\riscv_gcc\bin\riscv-none-elf-gcc.exe")
OBJCOPY = find_tool("riscv-none-elf-objcopy", r"D:\riscv_gcc\bin\riscv-none-elf-objcopy.exe")
NM = find_tool("riscv-none-elf-nm", r"D:\riscv_gcc\bin\riscv-none-elf-nm.exe")


@dataclass(frozen=True)
class Test:
    name: str
    top: str
    tb: Path
    sources: tuple[Path, ...]
    hex_file: Path | None = None
    full_only: bool = False
    vvp_args: tuple[str, ...] = ()


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

TESTS = (
    Test("rv32m_unit", "rv32m_unit_tb", TB / "rv32m_unit_tb.v",
         (ROOT / "modules" / "Hardware_Multiplier.v",)),
    Test("axi_adapter", "axi_adapter_tb", TB / "axi_adapter_tb.v",
         (ROOT / "modules" / "RV32_AXI_Adapter.v",)),
    Test("trap_rearm", "trap_rearm_tb", TB / "trap_rearm_tb.v",
         (ROOT / "modules" / "Trap_Controller.v",)),
    Test("jalr_load", "jalr_load_tb", TB / "jalr_load_tb.v", SOC_SOURCES,
         FIRMWARE / "jalr_load.hex"),
    Test("basic_memory_stack", "signature_tb", TB / "signature_tb.v", SOC_SOURCES,
         FIRMWARE / "basic_memory_stack.hex", vvp_args=("+PASS_NAME=basic_memory_stack",)),
    Test("pipeline_hazards", "signature_tb", TB / "signature_tb.v", SOC_SOURCES,
         FIRMWARE / "pipeline_hazards.hex", vvp_args=("+PASS_NAME=pipeline_hazards",)),
    Test("misaligned_csr", "misaligned_csr_tb", TB / "misaligned_csr_tb.v", SOC_SOURCES,
         FIRMWARE / "misaligned_csr.hex"),
    Test("irq_redirect", "irq_redirect_tb", TB / "irq_redirect_tb.v", SOC_SOURCES,
         FIRMWARE / "irq_redirect.hex"),
    Test("irq_boundaries", "irq_boundaries_tb", TB / "irq_boundaries_tb.v", SOC_SOURCES,
         FIRMWARE / "irq_boundaries.hex"),
    Test("context_restore", "context_restore_tb", TB / "context_restore_tb.v", SOC_SOURCES,
         FIRMWARE / "context_restore.hex", vvp_args=("+INTERRUPTS=4", "+PASS_NAME=context_restore")),
    Test("irq_stress", "context_restore_tb", TB / "context_restore_tb.v", SOC_SOURCES,
         FIRMWARE / "context_restore.hex", full_only=True,
         vvp_args=("+INTERRUPTS=500", "+PASS_NAME=irq_stress")),
    Test("rtthread_soft_reset", "rtthread_soft_reset_tb",
         TB / "rtthread_soft_reset_tb.v", SOC_SOURCES,
         ROOT / "rtthread.hex", full_only=True),
)

RTTHREAD_TEST_NAME = "rtthread_scheduler"
RTTHREAD_APP = ROOT / "software" / "rt_thread_app"
DHRYSTONE_TEST_NAME = "dhrystone_smoke"
DHRYSTONE_APP = ROOT / "software" / "apps" / "dhrystone"
DHRYSTONE_RUNTIME = ROOT / "software" / "runtime"
COREMARK_TEST_NAME = "coremark_smoke"
COREMARK_DIR = ROOT / "software" / "apps" / "coremark"
COREMARK_PORT = ROOT / "software" / "apps" / "wrappers" / "coremark"


def run(command: list[str], *, timeout: int = 180) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=ROOT,
        capture_output=True,
        text=True,
        errors="replace",
        timeout=timeout,
        check=False,
    )


def build_firmware(stem: str) -> None:
    source = FIRMWARE / f"{stem}.S"
    elf = OUT / f"{stem}.elf"
    binary = OUT / f"{stem}.bin"
    hex_file = FIRMWARE / f"{stem}.hex"
    commands = (
        [GCC, "-march=rv32im_zicsr", "-mabi=ilp32", "-nostdlib",
         "-nostartfiles", "-Wl,--gc-sections", "-T", str(FIRMWARE / "link.ld"),
         "-o", str(elf), str(source)],
        [OBJCOPY, "-O", "binary", str(elf), str(binary)],
        [PYTHON, str(ROOT / "software" / "rt_thread_app" / "makehex.py"),
         str(binary), str(hex_file)],
    )
    for command in commands:
        result = run(command)
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)


def build_rtthread_system_test() -> tuple[Path, tuple[str, ...]]:
    build_dir = OUT / "rtthread_system"
    build_dir.mkdir(parents=True, exist_ok=True)
    c_sources = sorted((RTTHREAD_APP / "src").glob("*.c")) + [
        RTTHREAD_APP / "board.c",
        RTTHREAD_APP / "libcpu" / "cpuport.c",
        FIRMWARE / "rtthread_system_test.c",
    ]
    asm_sources = [RTTHREAD_APP / "libcpu" / "context_gcc.S", RTTHREAD_APP / "startup.S"]
    objects: list[Path] = []
    common = [GCC, "-march=rv32im_zicsr", "-mabi=ilp32", "-O2",
              "-ffunction-sections", "-fdata-sections",
              f"-I{RTTHREAD_APP / 'include'}", f"-I{RTTHREAD_APP}",
              # Accelerate the RT-Thread test while leaving enough cycles for
              # one timer ISR to finish before the next interrupt arrives.
              "-DSYSTEM_CLOCK=10000000"]
    for source in c_sources + asm_sources:
        obj = build_dir / (source.name.replace(".c", ".o").replace(".S", ".o"))
        objects.append(obj)
        result = run([*common, "-c", str(source), "-o", str(obj)])
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)

    elf = build_dir / "rtthread_system.elf"
    binary = build_dir / "rtthread_system.bin"
    hex_file = FIRMWARE / "rtthread_system.hex"
    link = run([*common, "-T", str(RTTHREAD_APP / "link.lds"), "-nostartfiles",
                "-Wl,--gc-sections", "-lc", "-lm", "-lgcc", "-o", str(elf),
                *(str(obj) for obj in objects)])
    if link.returncode:
        raise RuntimeError(link.stdout + link.stderr)
    for command in (
        [OBJCOPY, "-O", "binary", str(elf), str(binary)],
        [PYTHON, str(RTTHREAD_APP / "makehex.py"), str(binary), str(hex_file)],
    ):
        result = run(command)
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)

    nm_result = run([NM, "-S", "-n", str(elf)])
    if nm_result.returncode:
        raise RuntimeError(nm_result.stdout + nm_result.stderr)
    symbols: dict[str, tuple[int, int]] = {}
    for line in nm_result.stdout.splitlines():
        fields = line.split()
        if len(fields) >= 4:
            try:
                symbols[fields[3]] = (int(fields[0], 16), int(fields[1], 16))
            except ValueError:
                pass

    required = {
        "MAIN_THREAD": "main_thread", "MAIN_STACK": "main_stack",
        "IDLE_THREAD": "idle", "IDLE_STACK": "rt_thread_stack",
        "TICK": "rt_tick", "NEST": "rt_interrupt_nest",
        "CURRENT": "rt_current_thread", "MAIN_PC": "main",
        "IDLE_PC": "rt_thread_idle_entry", "READY": "regression_ready",
        "DELAY_COUNT": "regression_delay_count", "DELAY_FAIL": "regression_delay_fail",
        "TICK_BEFORE": "regression_tick_before", "TICK_AFTER": "regression_tick_after",
    }
    missing = [symbol for symbol in required.values() if symbol not in symbols]
    if missing:
        raise RuntimeError("Missing RT-Thread test symbol(s): " + ", ".join(missing))
    args = []
    for plusarg, symbol in required.items():
        address, size = symbols[symbol]
        args.append(f"+{plusarg}={address:x}")
        if plusarg in {"MAIN_STACK", "IDLE_STACK", "MAIN_PC", "IDLE_PC"}:
            args.append(f"+{plusarg}_SIZE={size:x}")
    return hex_file, tuple(args)


def build_dhrystone_smoke() -> Path:
    build_dir = OUT / "dhrystone_smoke"
    build_dir.mkdir(parents=True, exist_ok=True)
    sources = [
        DHRYSTONE_APP / "dhrystone.c",
        DHRYSTONE_APP / "dhrystone_main.c",
        DHRYSTONE_RUNTIME / "syscalls.c",
        DHRYSTONE_RUNTIME / "crt0.S",
    ]
    common = [
        GCC, "-march=rv32i_zicsr_zifencei", "-mabi=ilp32", "-O2",
        "-nostdlib", "-nostartfiles", "-ffreestanding", "-std=gnu89",
        "-fwrapv", "-Wno-implicit-int", "-Wno-implicit-function-declaration",
        f"-I{DHRYSTONE_APP}", f"-I{DHRYSTONE_RUNTIME}",
        "-DNUMBER_OF_RUNS=20", "-DRISCV_CPU_HZ=100000000",
        "-DDHRY_FIXED_RUNS=1",
    ]
    objects: list[Path] = []
    for source in sources:
        obj = build_dir / (source.name.replace(".c", ".o").replace(".S", ".o"))
        objects.append(obj)
        result = run([*common, "-c", str(source), "-o", str(obj)])
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)

    elf = build_dir / "dhrystone_smoke.elf"
    hex_file = FIRMWARE / "dhrystone_smoke.hex"
    link = run([*common, "-T", str(DHRYSTONE_RUNTIME / "linker.ld"),
                *(str(obj) for obj in objects), "-lgcc", "-o", str(elf)])
    if link.returncode:
        raise RuntimeError(link.stdout + link.stderr)
    image = run([OBJCOPY, "-O", "verilog", "--verilog-data-width", "4",
                 str(elf), str(hex_file)])
    if image.returncode:
        raise RuntimeError(image.stdout + image.stderr)
    return hex_file


def build_coremark_smoke() -> Path:
    build_dir = OUT / "coremark_smoke"
    build_dir.mkdir(parents=True, exist_ok=True)
    sources = [COREMARK_DIR / name for name in (
        "core_main.c", "core_list_join.c", "core_matrix.c",
        "core_state.c", "core_util.c",
    )] + [COREMARK_PORT / "core_portme.c", DHRYSTONE_RUNTIME / "syscalls.c",
          DHRYSTONE_RUNTIME / "crt0.S"]
    common = [
        GCC, "-march=rv32im_zicsr_zifencei", "-mabi=ilp32", "-O2",
        "-nostdlib", "-nostartfiles", "-ffreestanding",
        f"-I{COREMARK_PORT}", f"-I{COREMARK_DIR}", f"-I{DHRYSTONE_RUNTIME}",
        "-DPERFORMANCE_RUN=1", "-DITERATIONS=1",
        "-DCOREMARK_CPU_HZ=100000000ULL", "-DCOREMARK_ALLOW_SHORT_RUN=1",
    ]
    objects: list[Path] = []
    for source in sources:
        obj = build_dir / (source.name.replace(".c", ".o").replace(".S", ".o"))
        objects.append(obj)
        result = run([*common, "-c", str(source), "-o", str(obj)])
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
    elf = build_dir / "coremark_smoke.elf"
    hex_file = FIRMWARE / "coremark_smoke.hex"
    link = run([*common, "-T", str(DHRYSTONE_RUNTIME / "linker.ld"),
                *(str(obj) for obj in objects), "-lgcc", "-o", str(elf)])
    if link.returncode:
        raise RuntimeError(link.stdout + link.stderr)
    image = run([OBJCOPY, "-O", "verilog", "--verilog-data-width", "4",
                 str(elf), str(hex_file)])
    if image.returncode:
        raise RuntimeError(image.stdout + image.stderr)
    return hex_file


def execute_test(test: Test) -> tuple[bool, float, str]:
    output = OUT / f"{test.name}.vvp"
    compile_command = [
        IVERILOG, "-g2012", "-s", test.top,
        f"-I{ROOT}", f"-I{ROOT.parent / 'verilog-axi' / 'rtl'}",
        f"-I{ROOT / 'modules' / 'cache'}", "-o", str(output),
        str(test.tb), *(str(source) for source in test.sources),
    ]
    started = time.perf_counter()
    compiled = run(compile_command)
    transcript = compiled.stdout + compiled.stderr
    if compiled.returncode:
        return False, time.perf_counter() - started, transcript

    simulate_command = [VVP, str(output)]
    if test.hex_file:
        simulate_command.append(f"+HEX_FILE={test.hex_file.as_posix()}")
    simulate_command.extend(test.vvp_args)
    try:
        simulated = run(simulate_command, timeout=480 if test.full_only else 120)
    except subprocess.TimeoutExpired as error:
        stdout = error.stdout or ""
        stderr = error.stderr or ""
        if isinstance(stdout, bytes):
            stdout = stdout.decode(errors="replace")
        if isinstance(stderr, bytes):
            stderr = stderr.decode(errors="replace")
        transcript += stdout + stderr
        transcript += "\nREGRESSION_FAIL: simulator wall-clock timeout\n"
        return False, time.perf_counter() - started, transcript
    transcript += simulated.stdout + simulated.stderr
    passed = simulated.returncode == 0 and f"REGRESSION_PASS: {test.name}" in transcript
    return passed, time.perf_counter() - started, transcript


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--quick", action="store_true", help="run fast CPU/RTL checks (default)")
    group.add_argument("--full", action="store_true", help="also boot RT-Thread twice")
    group.add_argument("--list", action="store_true", help="list available tests")
    parser.add_argument("tests", nargs="*", help="optional test names")
    args = parser.parse_args()

    if args.list:
        for test in TESTS:
            print(f"{test.name:24} {'full' if test.full_only else 'quick'}")
        print(f"{RTTHREAD_TEST_NAME:24} full")
        print(f"{DHRYSTONE_TEST_NAME:24} full")
        print(f"{COREMARK_TEST_NAME:24} full")
        return 0

    OUT.mkdir(parents=True, exist_ok=True)
    for firmware in ("jalr_load", "basic_memory_stack", "pipeline_hazards", "misaligned_csr",
                     "irq_redirect", "irq_boundaries", "context_restore"):
        build_firmware(firmware)
    selected = [test for test in TESTS if args.full or not test.full_only]
    rtthread_test: Test | None = None
    dhrystone_test: Test | None = None
    coremark_test: Test | None = None
    if args.full or RTTHREAD_TEST_NAME in args.tests:
        rt_hex, rt_args = build_rtthread_system_test()
        rtthread_test = Test(RTTHREAD_TEST_NAME, "rtthread_scheduler_tb",
                             TB / "rtthread_scheduler_tb.v", SOC_SOURCES,
                             rt_hex, full_only=True, vvp_args=rt_args)
        if args.full:
            selected.append(rtthread_test)
    if args.full or DHRYSTONE_TEST_NAME in args.tests:
        dhry_hex = build_dhrystone_smoke()
        dhrystone_test = Test(DHRYSTONE_TEST_NAME, "dhrystone_uart_tb",
                              TB / "dhrystone_uart_tb.v", SOC_SOURCES,
                              dhry_hex, full_only=True)
        if args.full:
            selected.append(dhrystone_test)
    if args.full or COREMARK_TEST_NAME in args.tests:
        coremark_hex = build_coremark_smoke()
        coremark_test = Test(COREMARK_TEST_NAME, "coremark_uart_tb",
                             TB / "coremark_uart_tb.v", SOC_SOURCES,
                             coremark_hex, full_only=True)
        if args.full:
            selected.append(coremark_test)
    if args.tests:
        known = ({test.name for test in TESTS} |
                 {RTTHREAD_TEST_NAME, DHRYSTONE_TEST_NAME, COREMARK_TEST_NAME})
        unknown = set(args.tests) - known
        if unknown:
            parser.error("unknown test(s): " + ", ".join(sorted(unknown)))
        selected = [test for test in TESTS if test.name in args.tests]
        if rtthread_test and RTTHREAD_TEST_NAME in args.tests:
            selected.append(rtthread_test)
        if dhrystone_test and DHRYSTONE_TEST_NAME in args.tests:
            selected.append(dhrystone_test)
        if coremark_test and COREMARK_TEST_NAME in args.tests:
            selected.append(coremark_test)

    failures = 0
    print(f"Running {len(selected)} regression test(s)...")
    for test in selected:
        passed, elapsed, transcript = execute_test(test)
        status = "PASS" if passed else "FAIL"
        print(f"[{status}] {test.name} ({elapsed:.2f}s)")
        if not passed:
            failures += 1
            print(transcript.rstrip())

    print(f"Summary: {len(selected) - failures} passed, {failures} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
