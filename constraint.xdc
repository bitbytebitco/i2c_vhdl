## Clock signal
set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS33} [get_ports i_CLK]
create_clock -add -period 50.000 -name sys_clk_pin -waveform {0.000 25.000} [get_ports i_CLK]

##Sch name = JA1
set_property PACKAGE_PIN J1 [get_ports io_SCL]
set_property IOSTANDARD LVCMOS33 [get_ports io_SCL]
set_property PULLUP TRUE [get_ports io_SCL]

set_property PACKAGE_PIN H2 [get_ports io_SDA]
set_property IOSTANDARD LVCMOS33 [get_ports io_SDA]
set_property PULLUP TRUE [get_ports io_SDA]


## Switch R15
set_property PACKAGE_PIN R2 [get_ports i_reset_n]
set_property IOSTANDARD LVCMOS33 [get_ports i_reset_n]
set_property PULLUP TRUE [get_ports i_reset_n]

## Configuration options, can be used for all designs
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]


### Clock signal
#set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS33} [get_ports i_CLK]
#create_clock -period 50.000 -name sys_clk_pin -waveform {0.000 25.000} -add [get_ports i_CLK]

###Sch name = JA1
#set_property PACKAGE_PIN J1 [get_ports io_SCL]
#set_property IOSTANDARD LVCMOS33 [get_ports io_SCL]
##set_property PULLUP TRUE [get_ports io_SCL]

###Sch name = JA9
#set_property PACKAGE_PIN H2 [get_ports io_SDA]
#set_property IOSTANDARD LVCMOS33 [get_ports io_SDA]
##set_property PULLUP TRUE [get_ports io_SDA]

### Switch R15
#set_property PACKAGE_PIN R2 [get_ports i_RESET]
#set_property IOSTANDARD LVCMOS33 [get_ports i_RESET]

### Configuration options, can be used for all designs
#set_property CONFIG_VOLTAGE 3.3 [current_design]
#set_property CFGBVS VCCO [current_design]



