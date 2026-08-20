## Clock signal (100 MHz oscillator -> Pin E3)
set_property LOC E3 [get_ports clock]
set_property IOSTANDARD LVCMOS33 [get_ports clock]

## CPU RESET button (C12, active-low / CPU_RESETN)
set_property LOC C12 [get_ports io_cpuResetN]
set_property IOSTANDARD LVCMOS33 [get_ports io_cpuResetN]

## Switches
## SW0 (Pattern bit 0)
set_property LOC J15 [get_ports {io_swPattern[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_swPattern[0]}]

## SW1 (Pattern bit 1)
set_property LOC L16 [get_ports {io_swPattern[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_swPattern[1]}]

## SW2 (Speed toggle)
set_property LOC M13 [get_ports io_swSpeed]
set_property IOSTANDARD LVCMOS33 [get_ports io_swSpeed]

## Onboard Status LEDs (LED0-LED1: Pattern, LED2-LED9: Active Row)
set_property LOC H17 [get_ports {io_ledPattern[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_ledPattern[0]}]

set_property LOC K15 [get_ports {io_ledPattern[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_ledPattern[1]}]

set_property LOC J13 [get_ports {io_ledActiveRow[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_ledActiveRow[0]}]

set_property LOC N14 [get_ports {io_ledActiveRow[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_ledActiveRow[1]}]

set_property LOC R18 [get_ports {io_ledActiveRow[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_ledActiveRow[2]}]

set_property LOC V17 [get_ports {io_ledActiveRow[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_ledActiveRow[3]}]

set_property LOC U17 [get_ports {io_ledActiveRow[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_ledActiveRow[4]}]

set_property LOC U16 [get_ports {io_ledActiveRow[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_ledActiveRow[5]}]

set_property LOC V16 [get_ports {io_ledActiveRow[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_ledActiveRow[6]}]

set_property LOC T15 [get_ports {io_ledActiveRow[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_ledActiveRow[7]}]

## PMOD JC: 8 Column Anodes (Active HIGH)
## Top Row (pins 1-4)
set_property LOC K1 [get_ports io_jc1]
set_property IOSTANDARD LVCMOS33 [get_ports io_jc1]

set_property LOC F6 [get_ports io_jc2]
set_property IOSTANDARD LVCMOS33 [get_ports io_jc2]

set_property LOC J2 [get_ports io_jc3]
set_property IOSTANDARD LVCMOS33 [get_ports io_jc3]

set_property LOC G6 [get_ports io_jc4]
set_property IOSTANDARD LVCMOS33 [get_ports io_jc4]

## Bottom Row (pins 7-10)
set_property LOC E7 [get_ports io_jc7]
set_property IOSTANDARD LVCMOS33 [get_ports io_jc7]

set_property LOC J3 [get_ports io_jc8]
set_property IOSTANDARD LVCMOS33 [get_ports io_jc8]

set_property LOC J4 [get_ports io_jc9]
set_property IOSTANDARD LVCMOS33 [get_ports io_jc9]

set_property LOC E6 [get_ports io_jc10]
set_property IOSTANDARD LVCMOS33 [get_ports io_jc10]

## PMOD JD: 8 Row Cathodes (Active LOW: 0 = GROUND)
## Top Row (pins 1-4)
set_property LOC H4 [get_ports io_jd1]
set_property IOSTANDARD LVCMOS33 [get_ports io_jd1]

set_property LOC H1 [get_ports io_jd2]
set_property IOSTANDARD LVCMOS33 [get_ports io_jd2]

set_property LOC G1 [get_ports io_jd3]
set_property IOSTANDARD LVCMOS33 [get_ports io_jd3]

set_property LOC G3 [get_ports io_jd4]
set_property IOSTANDARD LVCMOS33 [get_ports io_jd4]

## Bottom Row (pins 7-10)
set_property LOC H2 [get_ports io_jd7]
set_property IOSTANDARD LVCMOS33 [get_ports io_jd7]

set_property LOC G4 [get_ports io_jd8]
set_property IOSTANDARD LVCMOS33 [get_ports io_jd8]

set_property LOC G2 [get_ports io_jd9]
set_property IOSTANDARD LVCMOS33 [get_ports io_jd9]

set_property LOC F3 [get_ports io_jd10]
set_property IOSTANDARD LVCMOS33 [get_ports io_jd10]
