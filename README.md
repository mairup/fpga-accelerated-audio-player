# FPGA-Accelerated Audio Player

Real-time audio processing pipeline combining:
- **FPGA (Nexys A7 100T)**: Hardware DSP effects (Overdrive, Fuzz, Chorus, Phaser) with 128-LUT tables and 48 kHz 16-bit Mono I2S processing.
- **ESP32**: UDP receiver and I2S Master bus bridge using Toit.
- **Linux Client**: Real-time virtual audio sink relay capturing OS audio (PipeWire/PulseAudio) and sending UDP datagrams to the ESP32.

---

## Quick Commands

### 1. Flash FPGA Bitstream
Flashes the compiled bitstream (`fpga/TopAudioAccelerator.bit`) to the connected Nexys A7 100T board:
```bash
make flash
```

### 2. Deploy ESP32 Firmware
Runs the Toit audio streamer on the connected ESP32 via Jaguar over Wi-Fi:
```bash
make esp
# Or override IP:
make esp ESP_IP=192.168.5.72
```

### 3. Launch Desktop Audio Client
Captures your desktop audio and streams real-time UDP packets to the ESP32:
```bash
make client
# Or with options:
python3 client/audio_client.py --target 192.168.5.72
```

---

## Hardware Pin Mapping (Nexys A7 100T PMOD JA)

| Signal | Nexys A7 Pin | PMOD JA Pin | Description / Connected Device |
|---|---|---|---|
| **SPK_LEFT** | `C17` | JA[1] | Left Channel Speaker Output |
| **SPK_RIGHT**| `D18` | JA[2] | Right Channel Speaker Output |
| **SPK_EXTRA**| `E18` | JA[3] | Extra Audio Output |
| **CLK**      | `D17` | JA[7] | ESP32 GPIO 32 |
| **WS**       | `E17` | JA[8] | ESP32 GPIO 33 |
| **SDOUT**    | `F18` | JA[9] | ESP32 GPIO 12 |
| **SDIN**     | `G18` | JA[10]| ESP32 GPIO 13 |

---

## FPGA Switch Controls

- **SW[0]**: Master Output Enable / Mute (LED[0])
- **SW[1]**: FX Master Enable (LED[1])
- **SW[2]**: 128-LUT Overdrive (LED[2])
- **SW[3]**: 128-LUT Fuzz (LED[3])
- **SW[4]**: Chorus Effect (LED[4])
- **SW[5]**: 4-Stage APF Phaser (LED[5])
- **SW[14]**: Direct PWM Test Mode (LED[14])
- **SW[15]**: 440 Hz Test Tone Mode (LED[15])
