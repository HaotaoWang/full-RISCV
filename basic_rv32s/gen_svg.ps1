$yosysCmd = "read_verilog -sv -I. -Imodules RV32_SoC_AXI_Top.v modules/RV32I46F_5SP_MMIO.v modules/axi_clint.v modules/axi_ram_init.v modules/Unified_UART_Controller.v; hierarchy -top RV32_SoC_AXI_Top; proc; write_json netlist.json"
D:\Python312\Scripts\yowasp-yosys.exe -p $yosysCmd
npx netlistsvg netlist.json -o RV32_SoC_Architecture.svg
