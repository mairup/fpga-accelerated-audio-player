## Nexys A7 100T XDC Pin Constraints for TopAudioAccelerator

## 100 MHz System Clock
set_property LOC E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.0 -name sys_clk -waveform {0 5.0} [get_ports clk]

## CPU RESET button (C12, active-low / CPU_RESETN). Inverted in the Scala top
## so an active-high reset is derived. Normally HIGH = not reset; press to reset.
set_property LOC C12 [get_ports io_cpuResetN]
set_property IOSTANDARD LVCMOS33 [get_ports io_cpuResetN]

## I2S PMOD JA Header (Bottom Row)
## Wiring matching physical connections:
## ESP32 SDOUT (GPIO12) -> JA Pin 7  (D17) -> io_sdOut (input)
## ESP32 WS    (GPIO33) -> JA Pin 8  (E17) -> io_ws    (input)
## ESP32 CLK   (GPIO32) -> JA Pin 10 (G18) -> io_clk   (input)
## JA Pin 9 (F18) is now FREE / UNUSED

set_property LOC D17 [get_ports io_sdOut]
set_property IOSTANDARD LVCMOS33 [get_ports io_sdOut]

set_property LOC E17 [get_ports io_ws]
set_property IOSTANDARD LVCMOS33 [get_ports io_ws]

set_property LOC G18 [get_ports io_clk]
set_property IOSTANDARD LVCMOS33 [get_ports io_clk]

## Audio Output on PMOD JA Pin 1 (C17)
set_property LOC C17 [get_ports io_audPwmLeft]
set_property IOSTANDARD LVCMOS33 [get_ports io_audPwmLeft]

## Onboard Switches (SW0 - SW4): Master out, FX master, Overdrive, Chorus, Tremolo
set_property LOC J15 [get_ports io_swOutMaster]
set_property IOSTANDARD LVCMOS33 [get_ports io_swOutMaster]

set_property LOC L16 [get_ports io_swFxMaster]
set_property IOSTANDARD LVCMOS33 [get_ports io_swFxMaster]

set_property LOC M13 [get_ports io_swOverdrive]
set_property IOSTANDARD LVCMOS33 [get_ports io_swOverdrive]

set_property LOC R15 [get_ports io_swChorus]
set_property IOSTANDARD LVCMOS33 [get_ports io_swChorus]

set_property LOC R17 [get_ports io_swTremolo]
set_property IOSTANDARD LVCMOS33 [get_ports io_swTremolo]

## Debug switches: SW14=direct PWM bypass, SW15=test tone (sigma-delta)
set_property LOC U11 [get_ports io_swTestPwm]
set_property IOSTANDARD LVCMOS33 [get_ports io_swTestPwm]

set_property LOC V10 [get_ports io_swTestTone]
set_property IOSTANDARD LVCMOS33 [get_ports io_swTestTone]

## Onboard LEDs (LED0 - LED4): mirror the switches above them
set_property LOC H17 [get_ports io_ledOutMaster]
set_property IOSTANDARD LVCMOS33 [get_ports io_ledOutMaster]

set_property LOC K15 [get_ports io_ledFxMaster]
set_property IOSTANDARD LVCMOS33 [get_ports io_ledFxMaster]

set_property LOC J13 [get_ports io_ledOverdrive]
set_property IOSTANDARD LVCMOS33 [get_ports io_ledOverdrive]

set_property LOC N14 [get_ports io_ledChorus]
set_property IOSTANDARD LVCMOS33 [get_ports io_ledChorus]

set_property LOC R18 [get_ports io_ledTremolo]
set_property IOSTANDARD LVCMOS33 [get_ports io_ledTremolo]

## Diagnostic LEDs (LED6 - LED8)
set_property LOC U17 [get_ports io_ledClkAct]
set_property IOSTANDARD LVCMOS33 [get_ports io_ledClkAct]

set_property LOC U16 [get_ports io_ledWsAct]
set_property IOSTANDARD LVCMOS33 [get_ports io_ledWsAct]

set_property LOC V16 [get_ports io_ledRxValid]
set_property IOSTANDARD LVCMOS33 [get_ports io_ledRxValid]

## Volume Meter LEDs (LED9 - LED13, 5-bit)
set_property LOC T15 [get_ports {io_ledVolume[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_ledVolume[0]}]

set_property LOC U14 [get_ports {io_ledVolume[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_ledVolume[1]}]

set_property LOC T16 [get_ports {io_ledVolume[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_ledVolume[2]}]

set_property LOC V15 [get_ports {io_ledVolume[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_ledVolume[3]}]

set_property LOC V14 [get_ports {io_ledVolume[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_ledVolume[4]}]

## Debug LEDs (LED14 - LED15)
set_property LOC V12 [get_ports io_ledTestPwm]
set_property IOSTANDARD LVCMOS33 [get_ports io_ledTestPwm]

set_property LOC V11 [get_ports io_ledTestTone]
set_property IOSTANDARD LVCMOS33 [get_ports io_ledTestTone]

## PWM Audio DAC Output (mono 3.5mm jack, AUD_PWM & AUD_SD)
set_property LOC A11 [get_ports io_audPwm]
set_property IOSTANDARD LVCMOS33 [get_ports io_audPwm]

set_property LOC D12 [get_ports io_audSd]
set_property IOSTANDARD LVCMOS33 [get_ports io_audSd]

## UART Serial TX Pin (FT2232H Port B -> /dev/ttyUSB1)
set_property LOC D4 [get_ports io_txSerialPin]
set_property IOSTANDARD LVCMOS33 [get_ports io_txSerialPin]

## PMOD JC: 8 Pins (LED Matrix Anodes / Cathodes via LedMatrixDriver)
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

## PMOD JD: 8 Pins (LED Matrix Anodes / Cathodes via LedMatrixDriver)
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


