# Architecture

Three stages, two links. Audio flows desktop → FPGA; a second path on the FPGA turns the same samples into an 8×8 LED spectrum.

```
Linux desktop ──UDP/USB──▶ ESP32 ──I2S──▶ Nexys A7 100T
                                              │
                          ┌───────────────────┴────────────────────┐
                          ▼                                        ▼
                 AudioPipeline (FX)                       VisualizerTop (FFT)
                          │                                        │
                          ▼                                        ▼
                 SigmaDeltaDAC (PDM)              LedMatrixVisualizer + UART
                          │                                        │
                          ▼                                        ▼
              PMOD JA + 3.5 mm jack                  PMOD JC/JD (8×8 matrix)
```

## Stages

### 1. Client — `client/audio_client.py` (Python)

Loads a PulseAudio/PipeWire null sink (`fpga_audio_relay`), sets it as the default output, and captures its monitor with `parec` (mono, 16-bit LE, 48 kHz). Packs samples into 480-sample (10 ms) frames and sends them to the ESP32 over UDP (`:4440`) or USB serial (2 Mbaud). `--synth`, `--burst`, `--static-test` generate signals locally instead of capturing.

### 2. Bridge — `esp/audio_streamer.toit` (Toit, ESP32)

Receives frames over UDP or UART and drives an I2S master bus (SCK=GPIO32, WS=GPIO33, TX=GPIO12) at 48 kHz / 16-bit / mono. Buffers up to 25 frames; playback starts after 5 frames are pre-buffered. UART input takes priority while active.

### 3. DSP — `fpga/` (Chisel → Verilog, Nexys A7 100T)

Top module `TopAudioAccelerator`. The decoded audio feeds two independent paths:

| Path | Modules | Output |
|------|---------|--------|
| Audio | `I2sController` → `AudioPipeline` → `SigmaDeltaDAC` | PWM audio on PMOD JA + 3.5 mm jack |
| Visualizer | `I2sController` → `VisualizerTop` (FFT) → `LedMatrixVisualizer` | 8×8 LED matrix (PMOD JC/JD) + UART telemetry |

Effects are switch-gated: SW0 master out, SW1 FX master, SW2 overdrive, SW3 chorus, SW4 tremolo. SW14 and SW15 both inject a 440 Hz square-wave test tone into the DAC (bypassing the pipeline).

## Module → file

| Module | File |
|--------|------|
| `TopAudioAccelerator` | `fpga/src/main/scala/fpga/TopAudioAccelerator.scala` |
| `I2sController` | `fpga/src/main/scala/fpga/I2sController.scala` |
| `AudioPipeline` | `fpga/src/main/scala/dsp/AudioPipeline.scala` |
| `Overdrive` / `Chorus` / `Tremolo` | `fpga/src/main/scala/dsp/{Overdrive,Chorus,Tremolo}.scala` |
| `SigmaDeltaDAC` | `fpga/src/main/scala/fpga/SigmaDeltaDAC.scala` |
| `VisualizerTop` | `fpga/src/main/scala/dsp/visualizer/VisualizerTop.scala` |
| `FFTMagnitudeBinner` / `FFTTemporalTracker` / `SampleBuffer` | `fpga/src/main/scala/dsp/visualizer/` |
| `LedMatrixVisualizer` / `LedMatrixDriver` | `fpga/src/main/scala/dsp/visualizer/LedMatrixVisualizer.scala`, `fpga/src/main/scala/fpga/LedMatrixDriver.scala` |
| `UartTransmitter` | `fpga/src/main/scala/fpga/UartTransmitter.scala` |
