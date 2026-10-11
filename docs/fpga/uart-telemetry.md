# UART telemetry

The FPGA sends a 15-character ASCII status line over UART at 10 Hz.

## UartTransmitter — `fpga/UartTransmitter.scala`

8-N-1 UART (start + 8 data + stop), 115200 baud at 100 MHz (868 clock cycles per bit).

## Message — `fpga/TopAudioAccelerator.scala`

Every 10 Hz tick, the 8 band magnitudes and the peak volume are latched and sent as:

```
12345678 V:XY\r\n
```

- `12345678` — one ASCII digit per band, '1'–'8' (band level − 1).
- `V:XY` — peak volume as two hex digits (5-bit value, top bit in the first digit).

Sent on `io_txSerialPin` (pin D4, FT2232H Port B → `/dev/ttyUSB1`).
