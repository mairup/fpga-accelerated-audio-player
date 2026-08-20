## Clock signal (100 MHz oscillator -> Pin E3)
set_property LOC E3 [get_ports clock]
set_property IOSTANDARD LVCMOS33 [get_ports clock]

## CPU RESET button (C12, active-low / CPU_RESETN)
set_property LOC C12 [get_ports io_cpuResetN]
set_property IOSTANDARD LVCMOS33 [get_ports io_cpuResetN]

## Push Buttons
## BTNC (N17 - Mode toggle: Static DC vs Multiplexed)
set_property LOC N17 [get_ports io_btnC]
set_property IOSTANDARD LVCMOS33 [get_ports io_btnC]

## BTNU (M18 - Invert JD / Row polarity)
set_property LOC M18 [get_ports io_btnU]
set_property IOSTANDARD LVCMOS33 [get_ports io_btnU]

## BTND (P18 - Invert JC / Col polarity)
set_property LOC P18 [get_ports io_btnD]
set_property IOSTANDARD LVCMOS33 [get_ports io_btnD]

## Switches (SW0 - SW15)
set_property LOC J15 [get_ports {io_sw[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_sw[0]}]

set_property LOC L16 [get_ports {io_sw[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_sw[1]}]

set_property LOC M13 [get_ports {io_sw[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_sw[2]}]

set_property LOC R15 [get_ports {io_sw[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_sw[3]}]

set_property LOC R17 [get_ports {io_sw[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_sw[4]}]

set_property LOC T18 [get_ports {io_sw[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_sw[5]}]

set_property LOC U18 [get_ports {io_sw[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_sw[6]}]

set_property LOC R13 [get_ports {io_sw[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_sw[7]}]

set_property LOC T8 [get_ports {io_sw[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_sw[8]}]

set_property LOC U8 [get_ports {io_sw[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_sw[9]}]

set_property LOC R16 [get_ports {io_sw[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_sw[10]}]

set_property LOC T13 [get_ports {io_sw[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_sw[11]}]

set_property LOC H6 [get_ports {io_sw[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_sw[12]}]

set_property LOC U12 [get_ports {io_sw[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_sw[13]}]

set_property LOC U11 [get_ports {io_sw[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_sw[14]}]

set_property LOC V10 [get_ports {io_sw[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_sw[15]}]

## 16 Onboard LEDs (LED0 - LED15)
set_property LOC H17 [get_ports {io_leds[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_leds[0]}]

set_property LOC K15 [get_ports {io_leds[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_leds[1]}]

set_property LOC J13 [get_ports {io_leds[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_leds[2]}]

set_property LOC N14 [get_ports {io_leds[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_leds[3]}]

set_property LOC R18 [get_ports {io_leds[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_leds[4]}]

set_property LOC V17 [get_ports {io_leds[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_leds[5]}]

set_property LOC U17 [get_ports {io_leds[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_leds[6]}]

set_property LOC U16 [get_ports {io_leds[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_leds[7]}]

set_property LOC V16 [get_ports {io_leds[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_leds[8]}]

set_property LOC T15 [get_ports {io_leds[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_leds[9]}]

set_property LOC U14 [get_ports {io_leds[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_leds[10]}]

set_property LOC T16 [get_ports {io_leds[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_leds[11]}]

set_property LOC V15 [get_ports {io_leds[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_leds[12]}]

set_property LOC V14 [get_ports {io_leds[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_leds[13]}]

set_property LOC V12 [get_ports {io_leds[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_leds[14]}]

set_property LOC V11 [get_ports {io_leds[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_leds[15]}]

## PMOD JC: 8 Column Anodes
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

## PMOD JD: 8 Row Cathodes
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
