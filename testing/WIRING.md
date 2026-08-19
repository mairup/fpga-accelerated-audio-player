# Test Wiring

```text
esp32           FPGA JA
───────────────┬───────────────
GND            ├─> Pin 5 (or 11)
GPIO12 (SDOUT) ├─> Pin 7  (JA7  / D17 -> I2S Data from ESP)
GPIO33 (WS)    ├─> Pin 8  (JA8  / E17 -> I2S Word Select)
GPIO32 (BCLK)  └─> Pin 10 (JA10 / G18 -> I2S Bit Clock)
───────────────────────────────
Note: Pin 9 (F18) and ESP32 GPIO13 are FREE / UNUSED.
```
