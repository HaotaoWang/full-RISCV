import subprocess, sys

modules = [
    'RV32_SoC_AXI_Top.v',
    'modules/RV32I46F_5SP_MMIO.v',
    'modules/axi_ram_init.v',
    'modules/axi_clint.v',
    'D:/riscv/verilog-axi/rtl/axi_interconnect.v',
    'D:/riscv/verilog-axi/rtl/arbiter.v',
    'D:/riscv/verilog-axi/rtl/priority_encoder.v',
    'testbenches/BUFG.v',
    'testbenches/test_jal_lui_tb.v',
]

vvp_out = 'test_jal_lui.vvp'

cmd = ['iverilog', '-g2012', '-I', '.', '-I', 'modules/',
       '-y', 'modules/cache/',
       '-y', 'D:/riscv/verilog-axi/rtl/',
       '-o', vvp_out] + modules

print("=== Compiling JAL+LUI Test ===")
res = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='ignore')
if res.returncode != 0:
    print("Compilation failed!")
    print(res.stderr[:5000])
    sys.exit(1)

print("Compilation success! Running test...")
res2 = subprocess.run(['vvp', vvp_out], capture_output=True, text=True,
                      encoding='utf-8', errors='ignore', timeout=30)
if res2.stdout:
    print(res2.stdout)
if res2.stderr:
    print("STDERR:", res2.stderr[:1000])
