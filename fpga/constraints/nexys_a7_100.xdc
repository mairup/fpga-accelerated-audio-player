## Nexys A7 100T XDC Pin Constraints for TopAudioAccelerator

## 100 MHz System Clock
set_property LOC E3 [get_ports clock]
set_property IOSTANDARD LVCMOS33 [get_ports clock]

## CPU RESET button (C12, active-low / CPU_RESETN). Inverted in the Scala top
## so an active-high reset is derived. Normally HIGH = not reset; press to reset.
set_property LOC C12 [get_ports io_cpuResetN]
set_property IOSTANDARD LVCMOS33 [get_ports io_cpuResetN]

## I2S PMOD JA Header (Bottom Row)
## Wiring matching physical connections:
## ESP32 SDOUT (GPIO12) -> JA Pin 7  (D17) -> io_sdOut (input)
## ESP32 WS    (GPIO33) -> JA Pin 8  (E17) -> io_ws    (input)
## ESP32 BCLK  (GPIO32) -> JA Pin 10 (G18) -> io_bclk  (input)
## JA Pin 9 (F18) is now FREE / UNUSED

set_property LOC D17 [get_ports io_sdOut]
set_property IOSTANDARD LVCMOS33 [get_ports io_sdOut]

set_property LOC E17 [get_ports io_ws]
set_property IOSTANDARD LVCMOS33 [get_ports io_ws]

set_property LOC G18 [get_ports io_bclk]
set_property IOSTANDARD LVCMOS33 [get_ports io_bclk]

## DIY Stereo Audio Outputs on PMOD JA (Top Row)
set_property LOC C17 [get_ports io_audPwmLeft]
set_property IOSTANDARD LVCMOS33 [get_ports io_audPwmLeft]

set_property LOC D18 [get_ports io_audPwmRight]
set_property IOSTANDARD LVCMOS33 [get_ports io_audPwmRight]

set_property LOC E18 [get_ports io_audPwmExtra]
set_property IOSTANDARD LVCMOS33 [get_ports io_audPwmExtra]

## Onboard Switches (SW0 - SW5): out/fx master + 4 effects in processing order
set_property LOC J15 [get_ports io_swOutMaster]
set_property IOSTANDARD LVCMOS33 [get_ports io_swOutMaster]

set_property LOC L16 [get_ports io_swFxMaster]
set_property IOSTANDARD LVCMOS33 [get_ports io_swFxMaster]

set_property LOC M13 [get_ports io_swOverdrive]
set_property IOSTANDARD LVCMOS33 [get_ports io_swOverdrive]

set_property LOC R15 [get_ports io_swFuzz]
set_property IOSTANDARD LVCMOS33 [get_ports io_swFuzz]

set_property LOC R17 [get_ports io_swChorus]
set_property IOSTANDARD LVCMOS33 [get_ports io_swChorus]

set_property LOC T18 [get_ports io_swPhaser]
set_property IOSTANDARD LVCMOS33 [get_ports io_swPhaser]

## Debug switches: SW14=direct PWM bypass, SW15=test tone (sigma-delta)
set_property LOC U11 [get_ports io_swTestPwm]
set_property IOSTANDARD LVCMOS33 [get_ports io_swTestPwm]

set_property LOC V10 [get_ports io_swTestTone]
set_property IOSTANDARD LVCMOS33 [get_ports io_swTestTone]

## Onboard LEDs (LED0 - LED5): mirror the switches above them
set_property LOC H17 [get_ports io_ledOutMaster]
set_property IOSTANDARD LVCMOS33 [get_ports io_ledOutMaster]

set_property LOC K15 [get_ports io_ledFxMaster]
set_property IOSTANDARD LVCMOS33 [get_ports io_ledFxMaster]

set_property LOC J13 [get_ports io_ledOverdrive]
set_property IOSTANDARD LVCMOS33 [get_ports io_ledOverdrive]

set_property LOC N14 [get_ports io_ledFuzz]
set_property IOSTANDARD LVCMOS33 [get_ports io_ledFuzz]

set_property LOC R18 [get_ports io_ledChorus]
set_property IOSTANDARD LVCMOS33 [get_ports io_ledChorus]

set_property LOC V17 [get_ports io_ledPhaser]
set_property IOSTANDARD LVCMOS33 [get_ports io_ledPhaser]

## Diagnostic LEDs (LED6 - LED8)
set_property LOC U17 [get_ports io_ledBclkAct]
set_property IOSTANDARD LVCMOS33 [get_ports io_ledBclkAct]

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

