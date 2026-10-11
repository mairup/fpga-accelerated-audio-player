# Hardware pin map

Authoritative source is `fpga/constraints/nexys_a7_100.xdc` (physical FPGA pins), `fpga/src/main/scala/fpga/LedMatrixDriver.scala` (matrix routing), and `esp/audio_streamer.toit` (ESP32 GPIO). The top-level ports are defined in `TopAudioAcceleratorIO`.

## Clock & reset

| FPGA port | FPGA pin | Function |
|-----------|----------|----------|
| `clk` | E3 | 100 MHz system clock |
| `io_cpuResetN` | C12 | `CPU_RESETN`, active-low (inverted to active-high reset in the top module) |

## I2S input — PMOD JA, bottom row

The ESP32 is the I2S master. All three signals are inputs to the FPGA.

| Signal | Direction | FPGA port | FPGA pin | PMOD JA | ESP32 GPIO |
|--------|-----------|-----------|----------|---------|------------|
| Serial data | ESP32 → FPGA | `io_sdOut` | D17 | JA7 | GPIO12 |
| Word select | ESP32 → FPGA | `io_ws` | E17 | JA8 | GPIO33 |
| Bit clock | ESP32 → FPGA | `io_clk` | G18 | JA10 | GPIO32 |

PMOD JA pin 9 (F18) is not connected.

## Audio output

All four PWM outputs carry the same mono signal. `io_audSd` is tied high (audio enable).

| FPGA port | FPGA pin | Connector |
|-----------|----------|-----------|
| `io_audPwm` | A11 | 3.5 mm jack (`AUD_PWM`) |
| `io_audSd` | D12 | 3.5 mm jack (`AUD_SD`) |
| `io_audPwmLeft` | C17 | PMOD JA1 |
| `io_audPwmRight` | D18 | PMOD JA2 |
| `io_audPwmExtra` | E18 | PMOD JA3 |

## Switches

| Switch | FPGA port | FPGA pin | Function |
|--------|-----------|----------|----------|
| SW0 | `io_swOutMaster` | J15 | Master output enable |
| SW1 | `io_swFxMaster` | L16 | FX master bypass |
| SW2 | `io_swOverdrive` | M13 | Overdrive |
| SW3 | `io_swChorus` | R15 | Chorus |
| SW4 | `io_swTremolo` | R17 | Tremolo |
| SW14 | `io_swTestPwm` | U11 | Test tone (440 Hz square wave) |
| SW15 | `io_swTestTone` | V10 | Test tone (440 Hz square wave) |

## LEDs

| LED | FPGA port | FPGA pin | Meaning |
|-----|-----------|----------|---------|
| LED0 | `io_ledOutMaster` | H17 | SW0 state |
| LED1 | `io_ledFxMaster` | K15 | SW1 state |
| LED2 | `io_ledOverdrive` | J13 | SW2 state |
| LED3 | `io_ledChorus` | N14 | SW3 state |
| LED4 | `io_ledTremolo` | R18 | SW4 state |
| LED6 | `io_ledClkAct` | U17 | System clock running |
| LED7 | `io_ledWsAct` | U16 | WS toggling |
| LED8 | `io_ledRxValid` | V16 | RX valid |
| LED9–13 | `io_ledVolume[4:0]` | T15, U14, T16, V15, V14 | Volume, 5-bit |
| LED14 | `io_ledTestPwm` | V12 | SW14 state |
| LED15 | `io_ledTestTone` | V11 | SW15 state |

## UART

| FPGA port | FPGA pin | Destination |
|-----------|----------|-------------|
| `io_txSerialPin` | D4 | FT2232H Port B → `/dev/ttyUSB1`, 115200 baud |

## 8×8 LED matrix — PMOD JC + JD

Rows are anodes (active high), columns are cathodes (active low). Logical→physical routing from `LedMatrixDriver`.

Rows:

| Row | PMOD | FPGA pin |
|-----|------|----------|
| R1 | JC4 | G6 |
| R2 | JD8 | G4 |
| R3 | JD10 | F3 |
| R4 | JC9 | J4 |
| R5 | JD1 | H4 |
| R6 | JC8 | J3 |
| R7 | JC2 | F6 |
| R8 | JC1 | K1 |

Columns:

| Col | PMOD | FPGA pin |
|-----|------|----------|
| C1 | JC10 | E6 |
| C2 | JC3 | J2 |
| C3 | JD4 | G3 |
| C4 | JC7 | E7 |
| C5 | JD7 | H2 |
| C6 | JD3 | G1 |
| C7 | JD2 | H1 |
| C8 | JD9 | G2 |
