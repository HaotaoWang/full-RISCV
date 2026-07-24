# ==============================================================================
# Vivado Project Generation Script for RV32 AXI SoC
# ==============================================================================
# 使用方法:
# 1. 打开 Vivado
# 2. 在最下方的 Tcl Console 中输入:
#    cd {D:/riscv大项目/basic_rv32s}
#    source build_vivado.tcl
# ==============================================================================

set project_name "RV32_Kintex7_SoC"
set project_dir "./fpga/Vivado_Project"
set part_name "xc7k160tffg676-2"

# 1. 创建工程
create_project ${project_name} ${project_dir} -part ${part_name} -force

# 2. 添加你的 CPU 核心和 FPGA 顶层文件
# 注意: Hardware_Multiplier.v 和 RV32_AXI_Adapter.v 已经通过
#       RV32I46F_5SP_MMIO.v 里的 `include 引入了, 不要重复添加!
add_files -norecurse {
    ./fpga/My_Kintex7_RV32_SoC/FPGA_Top.v
    ./modules/RV32I46F_5SP_MMIO.v
    ./modules/axil_ram_init.v
    ./modules/headers/alu_src_select.vh
    ./modules/headers/rf_wd_select.vh
}
set_property is_global_include true [get_files ./modules/headers/alu_src_select.vh]
set_property is_global_include true [get_files ./modules/headers/rf_wd_select.vh]

# 3. 添加 verilog-axi 库的核心总线文件
add_files -norecurse {
    ../verilog-axi/rtl/axil_interconnect.v
    ../verilog-axi/rtl/arbiter.v
    ../verilog-axi/rtl/priority_encoder.v
}

# 4. 设置 Include 路径 (极其重要！因为你的代码里用了很多 `include)
set_property include_dirs { {./} {./modules} } [current_fileset]

# 5. 添加 Hex 初始化文件 (必须设为 Memory Initialization Files)
add_files -norecurse ./fpga/My_Kintex7_RV32_SoC/program.hex
set_property file_type "Memory Initialization Files" [get_files ./fpga/My_Kintex7_RV32_SoC/program.hex]

# 6. 添加管脚约束文件 (XDC)
add_files -fileset constrs_1 -norecurse ./fpga/My_Kintex7_RV32_SoC/Kintex_MK160FA.xdc

# 7. 设置顶层模块为 FPGA_Top
set_property top FPGA_Top [current_fileset]
update_compile_order -fileset sources_1

puts "========================================================="
puts "✅ Vivado 工程自动构建完成！"
puts "包含 CPU 核心、AXI 总线库、RAM 以及管脚约束。"
puts "现在你可以直接点击左侧的 'Generate Bitstream' 了！"
puts "========================================================="
