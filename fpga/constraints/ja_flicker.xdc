## Wire-check constraints for JaFreqDriver
## Drives every JA signal pin with a unique square wave:
##   JA1=1Hz  JA2=2Hz  JA3=4Hz  JA4=8Hz
##   JA7=16Hz JA8=32Hz JA9=64Hz JA10=128Hz

set_property LOC E3 [get_ports clock]
set_property IOSTANDARD LVCMOS33 [get_ports clock]

## CPU RESET button (C12, active-low / CPU_RESETN)
set_property LOC C12 [get_ports io_cpuResetN]
set_property IOSTANDARD LVCMOS33 [get_ports io_cpuResetN]

## PMOD JA Top Row (pins 1-4)
set_property LOC C17 [get_ports io_ja1]
set_property IOSTANDARD LVCMOS33 [get_ports io_ja1]

set_property LOC D18 [get_ports io_ja2]
set_property IOSTANDARD LVCMOS33 [get_ports io_ja2]

set_property LOC E18 [get_ports io_ja3]
set_property IOSTANDARD LVCMOS33 [get_ports io_ja3]

set_property LOC G17 [get_ports io_ja4]
set_property IOSTANDARD LVCMOS33 [get_ports io_ja4]

## PMOD JA Bottom Row (pins 7-10)
set_property LOC D17 [get_ports io_ja7]
set_property IOSTANDARD LVCMOS33 [get_ports io_ja7]

set_property LOC E17 [get_ports io_ja8]
set_property IOSTANDARD LVCMOS33 [get_ports io_ja8]

set_property LOC F18 [get_ports io_ja9]
set_property IOSTANDARD LVCMOS33 [get_ports io_ja9]

set_property LOC G18 [get_ports io_ja10]
set_property IOSTANDARD LVCMOS33 [get_ports io_ja10]
