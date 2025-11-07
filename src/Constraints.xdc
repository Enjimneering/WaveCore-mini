# System Signals
create_clock -add -name sys_clk_pin -period 40.00 -waveform {0 1} [get_ports { CLK }];
set_property -dict {PACKAGE_PIN E3  IOSTANDARD LVCMOS33} [get_ports CLK]
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports RST_N]

set_property -dict { PACKAGE_PIN T8    IOSTANDARD LVCMOS33 } [get_ports PITCH[0]]
set_property -dict { PACKAGE_PIN U8    IOSTANDARD LVCMOS33 } [get_ports PITCH[1]] 
set_property -dict { PACKAGE_PIN R16   IOSTANDARD LVCMOS33 } [get_ports PITCH[2]] 
set_property -dict { PACKAGE_PIN T13   IOSTANDARD LVCMOS33 } [get_ports PITCH[3]] 
set_property -dict { PACKAGE_PIN H6    IOSTANDARD LVCMOS33 } [get_ports PITCH[4]] 
set_property -dict { PACKAGE_PIN U12   IOSTANDARD LVCMOS33 } [get_ports PITCH[5]] 
set_property -dict { PACKAGE_PIN U11   IOSTANDARD LVCMOS33 } [get_ports PITCH[6]] 
set_property -dict { PACKAGE_PIN V10   IOSTANDARD LVCMOS33 } [get_ports PITCH[7]] 
# Output audio 
set_property -dict {PACKAGE_PIN A11 IOSTANDARD LVCMOS33} [get_ports {PWM}]

set_property -dict { PACKAGE_PIN D12   IOSTANDARD LVCMOS33 } [get_ports { aud_sd_o }];