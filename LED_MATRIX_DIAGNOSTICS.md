# 8x8 LED Matrix & FFT Visualizer: Diagnostics & Status

**Branch:** `experimental` (Commit `ff7336f`)

---

## 1. Summary of Current Work

All work has been committed to the `experimental` branch:
1. **FFT Audio Pipeline**:
   - `SampleBuffer.scala`: BRAM 1024-sample ring buffer with burst readout.
   - `FftCore.scala`: Chisel BlackBox wrapping the open-source `R22SdfFFT1024` streaming core.
   - `FFTMagnitudeBinner.scala`: Bit-reversal unravelling + Manhattan magnitude accumulation into 8 frequency bands.
   - `FFTTemporalTracker.scala`: Peak-hold envelope smoothing across FFT frames.
   - `VisualizerTop.scala`: End-to-end DSP pipeline.
   - **Unit Tests**: 10/10 unit tests passing in Chiseltest.
2. **UART Telemetry**:
   - `TopAudioAccelerator.scala`: Updated to transmit all 8 frequency band registers (`B0 B1 B2 B3 B4 B5 B6 B7\r\n`) at 10 Hz over `/dev/ttyUSB1`.
3. **LED Matrix Tester**:
   - `LedMatrixTestTop.scala` & `led_matrix_test.xdc`.

---

## 2. Why the Matrix Behaves Weirdly (Hardware Diagnostics)

If 3 rows and 1 column are completely dark, or if patterns look distorted, there are two primary physical root causes:

### A. Non-Sequential Matrix Pinouts (Most Common)
Standard discrete 8x8 LED matrix display modules (e.g. 1088AS, 1088BS, 788BS, 1588BS) have 16 physical pins, but **their physical pin numbers (1–16) are NOT sequential rows and columns**.

For example, on a standard **1088AS (Column-Cathode / Row-Anode)** module:
| Matrix Pin # | Function | Matrix Pin # | Function |
| :--- | :--- | :--- | :--- |
| **Pin 9** | Row 1 (Anode) | **Pin 13** | Column 1 (Cathode) |
| **Pin 14** | Row 2 (Anode) | **Pin 3** | Column 2 (Cathode) |
| **Pin 8** | Row 3 (Anode) | **Pin 4** | Column 3 (Cathode) |
| **Pin 12** | Row 4 (Anode) | **Pin 10** | Column 4 (Cathode) |
| **Pin 1** | Row 5 (Anode) | **Pin 6** | Column 5 (Cathode) |
| **Pin 7** | Row 6 (Anode) | **Pin 11** | Column 6 (Cathode) |
| **Pin 2** | Row 7 (Anode) | **Pin 15** | Column 7 (Cathode) |
| **Pin 5** | Row 8 (Anode) | **Pin 16** | Column 8 (Cathode) |

If you plugged pins 1–8 directly into PMOD JC and 9–16 into PMOD JD in numerical order, row and column pins are mixed up and polarities are crossed.

### B. Digilent PMOD Pin Layout
Nexys A7 PMOD connectors have 12 pins per port:
* **Top Row (Pins 1–4):** Pin 1, Pin 2, Pin 3, Pin 4 (+ Pin 5 GND, Pin 6 VCC)
* **Bottom Row (Pins 7–10):** Pin 7, Pin 8, Pin 9, Pin 10 (+ Pin 11 GND, Pin 12 VCC)

---

## 4. Final Verified Hardware Pinout (Nexys A7 PMOD JC & JD)

The empirical diagnostic observations resolved the full physical routing:
- **Rows**: Anodes (Active-HIGH / +3.3V)
- **Columns**: Cathodes (Active-LOW / 0V / Ground)

| Logical Line | Type | Polarity | Nexys A7 PMOD Pin | Header Pin # |
| :--- | :--- | :--- | :--- | :--- |
| **Row 1 (R1)** | Anode | Active HIGH (`1`) | `JC4` | PMOD JC Pin 4 |
| **Row 2 (R2)** | Anode | Active HIGH (`1`) | `JD8` | PMOD JD Pin 8 |
| **Row 3 (R3)** | Anode | Active HIGH (`1`) | `JD10` | PMOD JD Pin 10 |
| **Row 4 (R4)** | Anode | Active HIGH (`1`) | `JC9` | PMOD JC Pin 9 |
| **Row 5 (R5)** | Anode | Active HIGH (`1`) | `JD1` | PMOD JD Pin 1 |
| **Row 6 (R6)** | Anode | Active HIGH (`1`) | `JC8` | PMOD JC Pin 8 |
| **Row 7 (R7)** | Anode | Active HIGH (`1`) | `JC2` | PMOD JC Pin 2 |
| **Row 8 (R8)** | Anode | Active HIGH (`1`) | `JC1` | PMOD JC Pin 1 |
| **Col 1 (C1)** | Cathode | Active LOW (`0`) | `JC10` | PMOD JC Pin 10 |
| **Col 2 (C2)** | Cathode | Active LOW (`0`) | `JC3` | PMOD JC Pin 3 |
| **Col 3 (C3)** | Cathode | Active LOW (`0`) | `JD4` | PMOD JD Pin 4 |
| **Col 4 (C4)** | Cathode | Active LOW (`0`) | `JC7` | PMOD JC Pin 7 |
| **Col 5 (C5)** | Cathode | Active LOW (`0`) | `JD7` | PMOD JD Pin 7 |
| **Col 6 (C6)** | Cathode | Active LOW (`0`) | `JD3` | PMOD JD Pin 3 |
| **Col 7 (C7)** | Cathode | Active LOW (`0`) | `JD2` | PMOD JD Pin 2 |
| **Col 8 (C8)** | Cathode | Active LOW (`0`) | `JD9` | PMOD JD Pin 9 |

---

## 5. Unified Driver (`LedMatrixDriver.scala`)

The driver encapsulates this mapping as the single source of truth for both `LedMatrixTestTop` and the DSP visualizer, supporting hardware orientation selection (upright, 90° CW, 180°, 270° CW) via `SW3`/`SW4`.
