Here are the final configuration parameters for all 4 Chisel hardware DSP effect modules in the codebase:

---

### **1. 🎸 Overdrive (**`OverdriveChisel.scala`**)**

*Modeled after tube-like soft-clipping overdrive pedals.*

| Parameter          | Default Value | Data Type | Description                                                     |
|--------------------|---------------|-----------|-----------------------------------------------------------------|
| `driveGain`        | `8.0`         | `Double`  | Drive amplification gain (tuned to `8.0` for smooth saturation) |
| `brightnessFactor` | `0.50`        | `Double`  | High-pass pre-filter coefficient for note clarity               |
| `asymmetricBias`   | `1.35`        | `Double`  | Asymmetric bias scaling for negative audio swings               |
| `levelTrim`        | `0.35`        | `Double`  | Master output volume scaling                                    |

- **Hardware Architecture**: 32-segment uniform Piecewise Linear (PWL) approximation using 5-bit bit-sliced index lookups with Q1.31 linear interpolation.

---

### **2. ⚡ Fuzz (**`FuzzChisel.scala`**)**

*Modeled after classic asymmetric vintage germanium transistor Fuzz pedals.*

| Parameter      | Default Value | Data Type | Description                                              |
|----------------|---------------|-----------|----------------------------------------------------------|
| `fuzzGain`     | `50`          | `Int`     | Pre-gain integer amplification multiplier                |
| `posThreshold` | `0.50`        | `Double`  | Upper positive hard-clipping threshold                   |
| `negThreshold` | `0.40`        | `Double`  | Lower negative hard-clipping threshold (asymmetric bias) |
| `toneFactor`   | `0.60`        | `Double`  | Post-clipping IIR Low-Pass filter coefficient            |
| `levelTrim`    | `0.25`        | `Double`  | Master output volume scaling                             |

- **Hardware Architecture**: Asymmetric hard-clipping with first-order IIR low-pass tone shaping.

---

### **3. 🌊 Chorus (**`ChorusChisel.scala`**)**

*Modeled after the iconic BOSS CE-2 analog Chorus pedal.*

| Parameter       | Default Value | Data Type | Description                        |
|-----------------|---------------|-----------|------------------------------------|
| `rateHz`        | `1.2`         | `Double`  | LFO modulation sweep rate in Hz    |
| `depthMs`       | `2.5`         | `Double`  | Delay modulation depth swing in ms |
| `centerDelayMs` | `7.0`         | `Double`  | BBD analog base delay in ms        |
| `mix`           | `0.50`        | `Double`  | Dry/Wet blend (50% dry, 50% wet)   |
| `sampleRate`    | `44100.0`     | `Double`  | Audio sampling frequency           |

- **Hardware Architecture**: 2048-entry 32-bit RAM BBD circular delay buffer (1 FPGA Block RAM), 32-entry linearly-interpolated Sine ROM LFO, and first-order BBD warmth filter ($0.70 / 0.30$).

---

### **4. 🌀 Phaser (**`PhaserChisel.scala`**)**

*Modeled after the classic 4-stage MXR Phase 90 analog Phaser pedal.*

| Parameter    | Default Value | Data Type | Description                                                   |
|--------------|---------------|-----------|---------------------------------------------------------------|
| `rateHz`     | `0.8`         | `Double`  | LFO notch sweep speed in Hz                                   |
| `minFreqHz`  | `200.0`       | `Double`  | Minimum notch sweep frequency in Hz                           |
| `maxFreqHz`  | `2200.0`      | `Double`  | Maximum notch sweep frequency in Hz                           |
| `feedback`   | `0.40`        | `Double`  | Resonance feedback gain for deep sweep intensity              |
| `mix`        | `0.50`        | `Double`  | Dry/Wet mix (50% dry, 50% wet for maximum notch cancellation) |
| `sampleRate` | `44100.0`     | `Double`  | Audio sampling frequency                                      |

- **Hardware Architecture**: Single-cycle 4-stage cascaded All-Pass Filter (APF) pipeline with 100% throughput (1 sample per clock cycle) and 64-entry pre-computed linearly-interpolated coefficient ROM.