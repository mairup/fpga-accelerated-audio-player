# FPGA-Accelerated Audio Player — Documentation

Streams desktop audio to a Nexys A7 100T FPGA (over Wi-Fi or USB) for real-time DSP effects and an 8×8 LED FFT spectrum visualizer.

Three stages:

| Stage | Where | Does |
|-------|-------|------|
| Client | `client/audio_client.py` (Python) | Captures desktop audio, sends 10 ms frames |
| Bridge | `esp/audio_streamer.toit` (Toit, ESP32) | Receives frames, drives I2S master bus |
| DSP | `fpga/` (Chisel → Verilog, Nexys A7) | Decodes I2S, applies effects, PDM DAC, FFT visualizer |

## Index

- [Architecture](architecture.md) — components and how they connect
- [Data flow](data-flow.md) — signal path, timing, and formats
- [Hardware pin map](hardware-pinmap.md) — every FPGA pin and its function
- [Build & flash](build-and-flash.md) — Docker toolchain and `make` targets

FPGA:

- [DSP effects](fpga/dsp-effects.md) — overdrive, chorus, tremolo
- [I2S receiver](fpga/i2s-receiver.md)
- [Sigma-delta DAC](fpga/sigma-delta-dac.md)
- [FFT visualizer](fpga/fft-visualizer.md)
- [LED matrix](fpga/led-matrix.md)
- [UART telemetry](fpga/uart-telemetry.md)

Other:

- [ESP32 bridge](esp32/streamer.md)
- [Client](client/audio-client.md)

Every number and behavior in these pages is cited to its source file/line. Diagrams live in [`../diagrams/`](../diagrams/) until approved for merge.
