# FPGA-Accelerated Audio Player

A high-performance, real-time audio processing pipeline combining the power of FPGA hardware DSP, the wireless connectivity of the ESP32, and a flexible Linux desktop client. 

## 🌟 Key Features

- **Real-Time Hardware DSP**: Low-latency effects processing (Overdrive, Chorus, Tremolo) on a Nexys A7 100T FPGA.
- **Wireless Audio Streaming**: Stream your desktop audio directly to the ESP32 over Wi-Fi (UDP) or via high-speed USB Serial (2,000,000 baud).
- **Virtual Audio Sink**: The Linux client automatically creates a PulseAudio/PipeWire virtual sink to capture desktop audio seamlessly.
- **Test & Diagnostic Modes**: Built-in signal generators (440 Hz synth, 2 Hz burst, static patterns) for easy debugging.
- **LED Matrix Visualizer**: Real-time FFT-like volume band visualization driven directly by the FPGA on PMOD JC and JD.

## 🏗️ System Architecture

1. **Linux Desktop Client (Python)**:
   - Captures system audio using PulseAudio/PipeWire (`parec`/`pactl`).
   - Packages audio into 10ms frames (480 samples @ 48 kHz, Mono, 16-bit).
   - Transmits frames to the ESP32 via UDP datagrams or USB Serial.
   
2. **ESP32 Bridge (Toit)**:
   - Written in [Toit](https://toitlang.org/) for high-performance execution.
   - Listens for UDP packets on port 4440 or synchronizes USB serial packets using a custom header (`0x5A 0xA5 0x5A 0xA5`).
   - Drives the I2S Master bus, streaming audio data directly to the FPGA.

3. **FPGA DSP Engine (Nexys A7 100T)**:
   - Written in Chisel/Scala.
   - Implements a hardware I2S receiver.
   - Applies digital effects in real-time utilizing 128-LUT tables and efficient DSP techniques.
   - Outputs audio via the PMOD JA port.

## 🚀 Getting Started

### Prerequisites
- **Docker**: Used for containerized FPGA compilation (no local Scala/Chisel install required).
- **FPGA Flashing**: [openFPGALoader](https://github.com/trabucayre/openFPGALoader) to flash the Nexys A7.
- **ESP32**: [Jaguar (`jag`)](https://github.com/toitlang/jaguar) for deploying Toit code.
- **Client**: Python 3, PulseAudio/PipeWire (`pactl`, `parec`), `numpy`, `pyserial`.

### 1. Flash the FPGA
Compiles (if necessary) and flashes the Chisel-based hardware design to the Nexys A7 100T:
```bash
make fpga
```
*To just flash a prebuilt bitstream without building, run:* `make fpga flash`

### 2. Deploy the ESP32 Firmware
Uses Jaguar to compile and push the `audio_streamer.toit` script over Wi-Fi:
```bash
make esp
```
*You can override the target device: `make esp ESP_DEVICE=my-esp32`*

### 3. Launch the Audio Client
Streams your desktop audio to the ESP32. The script will automatically create a virtual audio device and set it as the default output.
```bash
make client
```
*To target a specific IP: `make client ESP_IP=192.168.5.73`*

*To stream via USB Serial instead of UDP (requires 2 Mbps baud rate):* `make client usb`

When you stop the client (Ctrl+C), it automatically restores your physical audio output.

## 🎛️ FPGA Switch Controls

The Nexys A7 100T switches dynamically control the DSP effects in real-time:

| Switch | LED | Function | Description |
|--------|-----|----------|-------------|
| **SW[0]** | LED[0] | Master Output | Master output enable / mute. |
| **SW[1]** | LED[1] | FX Master | Bypass or enable the effect chain. |
| **SW[2]** | LED[2] | Overdrive | Enables 128-LUT Overdrive distortion. |
| **SW[3]** | LED[3] | Chorus | Enables modulation effect. |
| **SW[4]** | LED[4] | Tremolo | Enables Tremolo effect. |
| **SW[14]**| LED[14]| PWM Test | Direct PWM test mode. |
| **SW[15]**| LED[15]| Test Tone | Injects a 440 Hz test tone at the input. |

## 🔌 Hardware Pin Mapping (Nexys A7 PMOD JA)

Connect your ESP32 to the Nexys A7 PMOD JA port as follows:

| Signal | Nexys A7 Pin | PMOD JA Pin | Connected ESP32 Pin | Description |
|--------|--------------|-------------|---------------------|-------------|
| **SPK_MONO** | `C17` | JA[1] | - | Mono Speaker Output |
| **CLK (SCK)**| `D17` | JA[7] | GPIO 32 | I2S Bit Clock (from ESP32) |
| **WS**       | `E17` | JA[8] | GPIO 33 | I2S Word Select / L-R Clock |
| **SDOUT**    | `F18` | JA[9] | GPIO 12 | I2S Data from ESP32 to FPGA |
| **SDIN**     | `G18` | JA[10]| GPIO 13 | I2S Data from FPGA to ESP32 |

*(Note: The built-in 3.5mm audio jack (`AUD_PWM`) is also driven with the Mono signal, alongside PMOD JA[1].)*

## 🛠️ Advanced Client Options

The `client/audio_client.py` script includes multiple modes for testing and diagnostics:

- **Target IP**: `python3 client/audio_client.py --target 192.168.1.100`
- **USB Serial**: `python3 client/audio_client.py --usb /dev/ttyUSB0` (sends over USB at 2M baud)
- **Continuous 440 Hz Tone**: `python3 client/audio_client.py --synth` (generates tone locally and streams it)
- **Burst Pattern**: `python3 client/audio_client.py --burst` (2 Hz ON/OFF pattern to test latency and dropouts)
- **Static Test Pattern**: `python3 client/audio_client.py --static-test` (sends raw hexadecimal patterns)
- **Restore Audio**: `python3 client/audio_client.py --restore` (cleans up any leftover PulseAudio virtual sinks)

---
*Developed for real-time hardware accelerated audio processing.*
