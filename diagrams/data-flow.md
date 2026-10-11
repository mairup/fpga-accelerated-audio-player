# Data flow

> DRAFT — kept separate from `docs/` pending approval. Merge into `docs/data-flow.md` only if confirmed.

```mermaid
flowchart TD
  A["parec capture<br/>mono, s16le, 48 kHz"] --> B["480-sample frames<br/>(10 ms, 960 bytes)"]
  B --> C["UDP :4440 (raw frame)<br/>or USB serial 2 Mbaud<br/>(sync word 5A A5 5A A5 + frame)"]
  C --> D["ESP32 I2S master<br/>48 kHz / 16-bit / mono"]
  D --> E["FPGA I2sController<br/>→ 32-bit Q31 samples"]
  E --> F["AudioPipeline<br/>overdrive / chorus / tremolo"]
  E --> G["VisualizerTop<br/>1024-pt FFT"]
  F --> H["SigmaDeltaDAC<br/>PDM → PWM"]
  G --> I["8-band magnitude + decay"]
  H --> J["PMOD JA + 3.5 mm jack"]
  I --> K["8×8 LED matrix<br/>PMOD JC/JD"]
  I --> L["UART 115200<br/>10 Hz ASCII telemetry"]
```
