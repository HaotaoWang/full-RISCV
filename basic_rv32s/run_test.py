import os
import subprocess
import glob

# Collect all .v files in modules and modules/cache
modules = glob.glob('modules/*.v') + glob.glob('modules/cache/*.v')

# Filter out old TOP files that contain missing dependencies
modules = [m for m in modules if 'SoC_TOP' not in m and 'RV32I37F' not in m and 'RV32I43F' not in m and 'RV32I46F.v' not in m and 'RV32I46F_5SP.v' not in m and 'RV32_AXI_Adapter.v' not in m and 'axil_ram_init.v' not in m]

# Target files
top_file = 'RV32_SoC_AXI_Top.v'
tb_file = 'testbenches/RV32_SoC_AXI_tb.v'

# axi files
axi_files = [
    'D:/riscv/verilog-axi/rtl/axi_interconnect.v',
    'D:/riscv/verilog-axi/rtl/arbiter.v',
    'D:/riscv/verilog-axi/rtl/priority_encoder.v'
]

# Build command
cmd = ['iverilog', '-I', '.', '-o', 'testbenches/results/RV32_SoC_AXI_Top_result.vvp'] + modules + axi_files + [top_file, tb_file]

print("Running iverilog...")
res = subprocess.run(cmd, capture_output=True, text=True)

if res.returncode != 0:
    print("Compilation failed!")
    print(res.stderr)
else:
    print("Compilation successful! Running vvp...")
    res2 = subprocess.run(['vvp', 'testbenches/results/RV32_SoC_AXI_Top_result.vvp'], capture_output=True, text=True)
    print(res2.stdout)
