# FPGA-Accelerated Audio Player

Streams desktop audio to a Nexys A7 100T FPGA (over Wi-Fi or USB) for real-time DSP effects and an 8×8 LED FFT spectrum visualizer.

## Documentation

- [Architecture](docs/architecture.md) — components, signal path, and timing
- [Hardware pin map](docs/hardware-pinmap.md) — every FPGA pin and its function
- [Build & flash](docs/build-and-flash.md) — Docker toolchain and `make` targets

FPGA:

- [DSP effects](docs/fpga/dsp-effects.md) — overdrive, chorus, tremolo
- [I2S receiver](docs/fpga/i2s-receiver.md)
- [Sigma-delta DAC](docs/fpga/sigma-delta-dac.md)
- [FFT visualizer](docs/fpga/fft-visualizer.md)
- [LED matrix](docs/fpga/led-matrix.md)
- [UART telemetry](docs/fpga/uart-telemetry.md)

Other:

- [ESP32 bridge](docs/esp32/streamer.md)
- [Client](docs/client/audio-client.md)
