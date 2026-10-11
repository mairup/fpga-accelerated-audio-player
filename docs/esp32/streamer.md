# ESP32 bridge

`esp/audio_streamer.toit` (Toit) receives audio frames and drives the I2S bus.

## Inputs

- **UDP** — listens on port 4440; accepts datagrams of exactly 960 bytes.
- **UART** — RX=GPIO3, TX=GPIO1, 2,000,000 baud; frames prefixed with sync word `5A A5 5A A5` (re-synchronized by `PacketSynchronizer`).

UART takes priority: while a UART frame is arriving, UDP datagrams are dropped.

## Output — I2S master

`i2s.Bus` master on SCK=GPIO32, WS=GPIO33, TX=GPIO12, configured 48 kHz / 16-bit / mono (written to both L/R slots).

## Flow

Frames go into a 25-deep channel queue. Playback starts after 5 frames are pre-buffered; before that, and when the queue drains, silence is written. Each frame is written to the I2S bus via `i2s-bus.write`.
