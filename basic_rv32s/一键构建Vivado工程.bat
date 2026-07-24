@echo off
echo ========================================================
echo Building RV32 AXI SoC Vivado Project...
echo ========================================================

vivado -mode batch -source build_vivado.tcl

echo ========================================================
echo Build complete. Please open fpga\Vivado_Project\RV32_Kintex7_SoC.xpr
echo ========================================================
pause
