#!/bin/bash
# RT-Thread 完整仿真测试脚本
# 用途：运行完整仿真并持续监控输出

echo "=========================================="
echo " RT-Thread JALR 修复验证仿真"
echo "=========================================="
echo ""

# 设置输出文件
LOG_FILE="rt_thread_complete_sim.log"
RESULT_FILE="jalr_test_result.txt"

# 清理旧文件
rm -f $LOG_FILE $RESULT_FILE sim.vvp

echo "[$(date +%H:%M:%S)] 开始编译..."

# 编译仿真
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
  modules/cache/icache_data_ram.v \
  modules/cache/icache_tag_ram.v \
  ../verilog-axi/rtl/axi_interconnect.v \
  ../verilog-axi/rtl/arbiter.v \
  ../verilog-axi/rtl/priority_encoder.v \
  testbenches/BUFG.v 2>&1 | tee compile.log

if [ $? -ne 0 ]; then
    echo "[$(date +%H:%M:%S)] ❌ 编译失败！"
    echo "查看 compile.log 了解详情"
    exit 1
fi

echo "[$(date +%H:%M:%S)] ✅ 编译成功"
echo ""
echo "[$(date +%H:%M:%S)] 开始运行仿真..."
echo "这将需要几分钟时间，请耐心等待..."
echo "实时输出正在写入: $LOG_FILE"
echo ""

# 运行仿真，实时显示进度
vvp sim.vvp 2>&1 | tee $LOG_FILE | while IFS= read -r line; do
    echo "$line"

    # 检测关键输出
    if echo "$line" | grep -q "JALR执行次数"; then
        echo "$line" >> $RESULT_FILE
    fi

    if echo "$line" | grep -q "JAL执行次数"; then
        echo "$line" >> $RESULT_FILE
    fi

    if echo "$line" | grep -q "RT-Thread"; then
        echo "[$(date +%H:%M:%S)] ✅ 检测到 RT-Thread 输出！" >&2
    fi

    if echo "$line" | grep -q "WB_JALR"; then
        echo "[$(date +%H:%M:%S)] ✅ 检测到 JALR 执行！" >&2
    fi
done

echo ""
echo "=========================================="
echo " 仿真完成"
echo "=========================================="

# 分析结果
if [ -f $RESULT_FILE ]; then
    echo "关键结果："
    cat $RESULT_FILE
else
    echo "未找到结果文件，提取最后50行："
    tail -50 $LOG_FILE
fi

echo ""
echo "完整日志: $LOG_FILE"
echo "=========================================="
