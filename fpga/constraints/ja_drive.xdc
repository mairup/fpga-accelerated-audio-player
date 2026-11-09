## JA pin scan testbench constraints
## JA1..JA8 on Nexys A7 100 (Pmod JA), telemetry on FT2232 port B

set_property -dict { LOC E3 IOSTANDARD LVCMOS33 } [get_ports clock]



set_property -dict { LOC C17 IOSTANDARD LVCMOS33 } [get_ports {io_jaPins[0]}]
set_property -dict { LOC D17 IOSTANDARD LVCMOS33 } [get_ports {io_jaPins[1]}]
set_property -dict { LOC E17 IOSTANDARD LVCMOS33 } [get_ports {io_jaPins[2]}]
set_property -dict { LOC F18 IOSTANDARD LVCMOS33 } [get_ports {io_jaPins[3]}]
set_property -dict { LOC G18 IOSTANDARD LVCMOS33 } [get_ports {io_jaPins[4]}]
set_property -dict { LOC H18 IOSTANDARD LVCMOS33 } [get_ports {io_jaPins[5]}]
set_property -dict { LOC J18 IOSTANDARD LVCMOS33 } [get_ports {io_jaPins[6]}]
set_property -dict { LOC K18 IOSTANDARD LVCMOS33 } [get_ports {io_jaPins[7]}]

set_property -dict { LOC D4 IOSTANDARD LVCMOS33 } [get_ports io_txSerialPin]

create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports clock]
