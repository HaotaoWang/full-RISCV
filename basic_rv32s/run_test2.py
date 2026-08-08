import subprocess
import glob

cache_files = glob.glob('modules/cache/*.v')
axi_files = [
    'D:/riscv/verilog-axi/rtl/axi_interconnect.v',
    'D:/riscv/verilog-axi/rtl/arbiter.v',
    'D:/riscv/verilog-axi/rtl/priority_encoder.v'
]

cmd = ['iverilog', '-I', '.', '-o', 'soc_test.vvp', 'RV32_SoC_AXI_Top.v', 'testbenches/RV32_SoC_AXI_tb.v', 'modules/RV32I46F_5SP_MMIO.v', 'modules/axi_ram_init.v', 'modules/axi_clint.v'] + cache_files + axi_files

res = subprocess.run(cmd, capture_output=True)
if res.returncode != 0:
    print("COMPILE ERROR:")
    print(res.stderr.decode('utf-8', errors='ignore'))
else:
    res2 = subprocess.run(['vvp', 'soc_test.vvp'], capture_output=True)
    print("VVP OUTPUT:")
    print(res2.stdout.decode('utf-8', errors='ignore'))
