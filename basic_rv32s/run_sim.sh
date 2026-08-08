#!/bin/bash
# RT-Thread 仿真运行脚本

cd "$(dirname "$0")"

echo "=== 编译 Verilog 仿真 ==="
iverilog -g2012 -o sim.vvp \
  -I../verilog-axi/rtl \
  -Imodules/cache \
  testbenches/RV32_SoC_AXI_tb.v \
  RV32_SoC_AXI_Top.v \
  modules/RV32I46F_5SP_MMIO.v \
  modules/axi_clint.v \
  modules/axi_ram_init.v \
  modules/cache/dcache.v \
  modules/cache/dcache_axi.v \
  modules/cache/dcache_axi_axi.v \
  modules/cache/dcache_core.v \
  modules/cache/dcache_core_data_ram.v \
  modules/cache/dcache_core_tag_ram.v \
  modules/cache/dcache_if_pmem.v \
  modules/cache/dcache_mux.v \
  modules/cache/dcache_pmem_mux.v \
  modules/cache/icache.v \
  ../verilog-axi/rtl/axi_interconnect.v \
  ../verilog-axi/rtl/arbiter.v \
  ../verilog-axi/rtl/priority_encoder.v \
  testbenches/BUFG.v

if [ $? -eq 0 ]; then
    echo "=== 编译成功，运行仿真 ==="
    vvp sim.vvp
else
    echo "=== 编译失败 ==="
    exit 1
fi
