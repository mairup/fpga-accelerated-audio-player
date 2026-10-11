# Client

`client/audio_client.py` (Python) captures desktop audio and streams it to the ESP32.

## Capture

1. Loads a PulseAudio/PipeWire null sink `fpga_audio_relay` and sets it as the default output, so desktop audio plays into it.
2. Captures the sink's monitor with `parec` — mono, 16-bit little-endian, 48 kHz, 10 ms latency.
3. Packs samples into 480-sample frames (960 bytes).

## Transport

- **UDP** (default): each frame sent as-is to `ESP32:4440`.
- **USB serial** (`--usb <port>`): frame prefixed with sync word `5A A5 5A A5`, 2 Mbaud.

## Modes

| Flag | Behavior |
|------|----------|
| (default) | capture + stream |
| `--synth` | stream a 440 Hz tone |
| `--burst` | 2 Hz on/off pattern (latency test) |
| `--static-test` | fixed `65 87 34 12` pattern |
| `--restore` | restore audio and clean up null sinks |

On stop (Ctrl+C) the client restores the previous default sink and unloads the null sinks.
