### ==========================================================================
### Kintex-7 MK160FA XDC 管脚约束文件
### Target Board: MK160TFA (Kintex-7 XC7K160T-2FFG676)
### ==========================================================================
### 管脚信息来源: 
###   核心板原理图 MK7XCORE676_20220110.pdf (Page 3)
###   底板原理图 MK7160FA20190818.pdf (Page 3, 7)
### ==========================================================================

##########################################################################################
# 系统时钟 (100MHz, 来自核心板 IC2 晶振)
##########################################################################################
set_property -dict { PACKAGE_PIN AA3   IOSTANDARD LVCMOS18 } [get_ports { sys_clk }]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports sys_clk]

##########################################################################################
# 复位按键 (使用底板 KEY1, Active Low: 按下=0, 松开=1)
# 添加内部上拉确保松开时为高电平
##########################################################################################
set_property -dict { PACKAGE_PIN J13   IOSTANDARD LVCMOS33   PULLUP TRUE } [get_ports { sys_rst_n }]

##########################################################################################
# LED 输出 (底板 4 个 LED)
##########################################################################################
set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { led[0] }]
set_property -dict { PACKAGE_PIN H14   IOSTANDARD LVCMOS33 } [get_ports { led[1] }]
set_property -dict { PACKAGE_PIN J10   IOSTANDARD LVCMOS33 } [get_ports { led[2] }]
set_property -dict { PACKAGE_PIN J11   IOSTANDARD LVCMOS33 } [get_ports { led[3] }]

##########################################################################################
# UART (CP2104 USB-to-Serial, 底板 Page 3)
# 注意: CP2104_TXD 是芯片发送端, 对应 FPGA 的接收端 (RX)
#       CP2104_RXD 是芯片接收端, 对应 FPGA 的发送端 (TX)
##########################################################################################
set_property -dict { PACKAGE_PIN V24   IOSTANDARD LVCMOS33 } [get_ports { uart_rx }]
set_property -dict { PACKAGE_PIN U22   IOSTANDARD LVCMOS33 } [get_ports { uart_tx }]

##########################################################################################
# 时序约束
##########################################################################################
set_false_path -from [get_ports sys_rst_n]

##########################################################################################
# 配置约束
##########################################################################################
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
