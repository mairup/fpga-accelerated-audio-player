# FPGA-Accelerated Audio Player - High-Level Architecture

## Overview

This document describes the complete hardware/software stack for real-time audio DSP on FPGA. The system consists of three synchronized components:

1. **FPGA Core (Nexys A7 100T)**: Processes 48 kHz mono audio through a cascaded DSP pipeline with hardware-accelerated effects.
2. **ESP32 Firmware (Toit)**: Receives UDP audio packets from the PC client and drives an I2S bus that feeds the FPGA.
3. **Linux Client**: Captures system audio and streams encoded UDP packets back to the ESP32, completing the loop.

The signal flow is bidirectional: PC \u2192 ESP32 \u2192 FPGA \u2192 ESP32 \u2192 speakers.

---

## 1. FPGA Design

### 1.1 Top-Level Module

**`TopAudioAccelerator.scala`** is the system integrator. It instantiates four major subsystems and wires them together:

| Instance | Role |
|----------|------|
| `I2sController` | I2S slave receiver (ESP32 \u2192 FPGA) |
| `AudioPipeline` | Cascaded DSP effects (Overdrive \u2192 Chorus \u2192 Tremolo) |
| `SigmaDeltaDAC` | PDM audio output for PMOD JA |
| `VisualizerTop` | 8-band magnitude analysis + ASCII telemetry |
| `LedMatrixVisualizer` | Onboard 8\u00d78 LED matrix spectrum display |

### 1.2 Clock & Reset Domain

- **System clock**: 100 MHz (board clock)
- **I2S sample rate**: 48 kHz (derived)
- **BCLK**: 100 MHz / 48000 \u2248 2083 cycles per frame
- **Reset**: External pin `cpuResetN` (active low), asserted by Jaguar or board switches

All subsystems run in the same clock domain with reset synchronizers at their inputs.

### 1.3 I2S Receiver (`I2sController`)

The FPGA acts as a *slave* I2S receiver. ESP32 drives I2S in master mode.

| Pin | Direction |
|-----|-----------|
| `bclk` | I/O, toggles 100 MHz bit clock |
| `ws` | Input, active-low for left channel |
| `sdOut` (ESP32 SDIN) | Input, 16\u2011bit mono sample stream |

**Timing**:
- 32 BCLK cycles between WS edges
- First 2\u201316 BCLKs are a 16\u2011bit left-aligned value plus padding (to match ESP32's 32\u2011bit frame size)
- The valid sample is reconstructed as a signed 32\u2011bit integer and placed on `io.pcmRx` with `pcmRxValid` asserted only on the left channel.

See `I2sController.scala:33-56`.

### 1.4 Audio DSP Pipeline (`AudioPipeline`)

A single 32\u2011bit signed sample flows through three parallel-effect stages. FX Master switch (`swFxMaster`) gates the whole pipeline; individual switch lines (`swOverdrive`, `swChorus`, `swTremolo`) select each stage.

**Stage order**:
1. **Overdrive** (pass-through if disabled) \u2192 `sampleIn` \u2192 `overdrive` \u2192 `stage1`
2. **Chorus** \u2192 `stage2`
3. **Tremolo** \u2192 `io.sampleOut`

Each stage outputs valid flag (`io.outValid`) which becomes the `sampleValid` for the next stage. The pipeline is *sample-aligned* (no latency insertion) and *continuous* (no gaps).

See `AudioPipeline.scala:23-57`.

### 1.5 Effect Modules

#### Chorus (`Chorus.scala`)
- **Architecture**: Feedback delay line with LFO-modulated delay
- **Buffer**: 4096-sample dual-port BRAM
- **LFO**: 512-entry sine ROM, quarter-resolution index, generates smooth modulation depth
- **Delay formula**:
  \[
  D = D_{\text{center}} + \text{mod}(S_{31})
  \]
  where \(D_{\text{center}}\) is a configurable offset (50 ms \u2248 2400 samples at 48 kHz) and \(S_{31}\) is the LFO sine sample sign-extended to 32 bits.
- **Smoothing**: The wet signal uses a 0.25 + 0.75 low-pass (previous smoothed wet + raw wet) to avoid pump artifacts.
- **Mix**: \(\alpha \cdot \text{dry} + \beta \cdot \text{wet}\) with \(\alpha = \beta = 0.5\).

Configuration constants:
```scala
rateHz      = 0.25     // LFO frequency
depthMs     = 10.0     // modulation depth
centerDelayMs = 50.0   // base delay
alpha       = 0.5
beta        = 0.5
```

#### Overdrive & Tremolo
- Implemented as single-cycle lookup-table or sample-rate multiplexer stages. Not expanded here; see their respective source files for details.

### 1.6 DAC Output (`SigmaDeltaDAC`)

The final sample from the DSP pipeline is sent to a sigma-delta modulator, which outputs a 1-bit PWM stream suitable for the onboard 3.5 mm jack or the PMOD JA speaker outputs.

**Algorithm**:
1. **Range fold**: 32-bit signed \(-2^{31} \dots 2^{31}\!-\!1\) maps to 32-bit unsigned \(0 \dots 2^{32}\!-\!1\).
2. **Linear interpolator**: A 2083-cycle ramp (100 MHz / 48 kHz) steps from `currentSample` to `targetSample` by delta \((\text{target} - \text{current}) / 2048\), preventing clicks when samples arrive sparsely.
3. **Accumulator**: `accumulator = accumulator(31,0) + currentSample`. The MSB carry-out is the 1-bit PDM stream.

**Output mapping**:
- Onboard: `audPwm` (Pin A11)
- PMOD JA: split to three wires `audPwmLeft/Right/Extra` (all tied together in this design, effectively mono to a 3-wire speaker)

See `SigmaDeltaDAC.scala:6-38`.

### 1.7 Visualizer Subsystem

Two independent visualizers:

**Spectrum Analyzer** (`VisualizerTop`):
- Feeds `I2sController.pcmRx` directly into an FFT-like magnitude accumulator.
- Produces `catVolume`: an 8-element packed value encoding each band's ASCII character intensity (8 bits per band).
- Triggers once per 10 ms (via a prescaler) to update the LED matrix and UART ASCII line.

**LED Matrix** (`LedMatrixVisualizer`):
- 8\u00d78 grid on PMOD JC (row 1) and JD (row 2).
- Decodes `catVolume` bits to segment-select signals.
- Multiplexing at 100 kHz ensures visible steady-state patterns.

### 1.8 Direct USB-UART Audio Input

The ASCII telemetry output was removed. The FT2232H UART (`/dev/ttyUSB1`, FPGA pin C4) is now an audio input at 2 Mbaud, 8N1. The TX pin (D4) is held idle-high.

Packet format (sent by `client/guitar_direct.py`):

```
0x5A 0xA5 <32 x int16 little-endian mono samples>
```

`UartAudioReceiver` parses packets into a 1024-sample FIFO and plays them out at ~48 kHz. The playout period switches between 2082 and 2085 clock cycles depending on whether the FIFO holds more or fewer than 128 samples (2.7 ms). This compensates for clock drift between the host audio interface and the FPGA oscillator. The pitch deviation is about 0.07%.

Source selection is automatic. While UART packets have arrived in the last 100 ms, the UART stream feeds the pipeline, visualizer and LEDs. Otherwise the I2S input from the ESP32 is used.

---

## 2. ESP32 Firmware

### 2.1 Hardware

- **FPGA I2S pins mapped to ESP32 GPIOs**:
  | Signal | FPGA Pin | ESP32 GPIO |
  |--------|----------|------------|
  | BCLK   | D17 / PMOD JA7 | 32 |
  | WS     | E17 / PMOD JA8 | 33 |
  | SDOUT  | F18 / PMOD JA9 | 12 (ESP32 Tx) |

- **UART** (Jaguar monitor and custom sync protocol): RX=GPIO3, TX=GPIO1, 2 Mbaud

- **UDP port**: 4440

### 2.2 Network Stack

Opens a UDP socket bound to port 4440, receiving 960-byte frames from the PC client. Frames are accepted only if USB activity has completed (`usb-active-until` check).

### 2.3 I2S Master Bus

**Configuration** (executed in `init-i2s`):
- Sample rate: 48 kHz
- Bits per sample: 16
- Slots: mono both directions
  - TX: `SLOTS-MONO-BOTH` (16-bit write per frame)
  - RX: `SLOTS-MONO-LEFT` (16-bit read from FPGA's SDIN)

The I2S bus is started immediately after configuration; BCLK is driven continuously by the ESP32, and the `write-frame` task always pushes a pre-filled zero buffer if the input queue is empty.

### 2.4 Input Queues

- **`RX-QUEUE`**: 25-frame circular buffer (960 bytes each).
- **Prebuffer policy**: If queue size < 5 frames, the loop writes a silence buffer instead of blocking, keeping the I2S clock stable.

### 2.5 Custom UART Sync Protocol

FPGA sends diagnostic blocks prefixed by a 4-byte synchronization sequence: `0x5A 0xA5` followed by payload (16 bytes). The UART reader parses this header and copies the payload into a local buffer, then enqueues 960-byte UDP frames for the I2S streamer.

### 2.6 Main Loop Structure

```
task: i2s-write-loop    // always blocking, never stops BCLK
task: uart-read-loop    // decodes sync packets, feeds RX-QUEUE
main: receive UDP, enqueue (up to MAX-QUEUE-FRAMES)
```

This design avoids race conditions and guarantees that audio never skips.

---

## 3. Linux Client

The client bridges the PC's audio subsystem to the ESP32:

1. **Capture**: Uses PipeWire/PulseAudio virtual audio sink (via `pasuspender` or JACK) to grab the system mixer.
2. **Encode**: Downsamples (if necessary) and packs samples into 960-byte UDP datagrams (144 samples \u00d7 2 bytes/sample = 288 bytes for mono; 960 is chosen for simplicity).
3. **Send**: UDP packets to 192.168.5.72:4440.
4. **Playback**: The PC's speakers never play the original audio; only the ESP32/FPGA path does. The client also prints a debug log showing packet counts and any send failures.

---

## 4. Switch & LED Mapping

The Nexys A7 board has a row of 16 switches on the main panel. The design maps the following:

| Switch | LED (if any) | Function |
|--------|--------------|----------|
| SW0 | LED0 | Output master (mute when off) |
| SW1 | LED1 | FX master (bypasses entire DSP when off) |
| SW2 | LED2 | Enable 128-LUT Overdrive |
| SW3 | LED3 | Enable 128-LUT Fuzz |
| SW4 | LED4 | Enable Chorus |
| SW5 | LED5 | Enable 4-stage APF Phaser |
| SW14 | LED14 | Direct PWM test mode (bypasses DSP, sends 440 Hz tone) |
| SW15 | LED15 | 440 Hz test tone mode |

The LEDs provide immediate visual feedback for the FPGA and Jaguar UART monitors.

---

## 5. Data Flow Diagram

```
              +----------+
              |  PC Client|
              +----+-----+
                   |  UDP 4440
                   v
        +----------+-----------+
        | ESP32 (I2S Master)   |
        | + 960-byte frames    |<--- UART sync decode
        +----+-----------------+
             |  I2S (slave rx)
             v
 +-----------------------+
 |  FPGA TopAudioAcceler |
 |  I2sController        |-----> PCM samples (32b)
 |  AudioPipeline        |  Overdrive -> Chorus -> Tremolo
 |  SigmaDeltaDAC        |-----> PWM (1-bit)
 |  VisualizerTop        |  (spectrum to UART/LEDs)
 +-----------------------+
             ^
             | PWM
             v
        +-------------+
        | Onboard DAC |
        | PMOD JA Out |--> Speakers
        +-------------+
```

---

## 6. Design Constraints

- **Clock frequencies**: FPGA 100 MHz, I2S 48 kHz (fixed by hardware BCLK/WS ratio).
- **DSP latency**: Negligible (effectively 1 sample per pipeline stage), but the Chorus uses a 4096-sample BRAM with feedback, introducing ~42 ms round-trip.
- **Memory**: Dual-port BRAMs for the chorus delay line; 128-entry LUT ROMs for Overdrive/Fuzz (not detailed here).
- **GPIO limits**: Single PMOD JA carries all audio paths; other PMODs are unused in this configuration.

---

## 7. Next Steps

This high-level document covers the complete architecture, module interconnections, and timing assumptions. The following iteration will drill down into each DSP algorithm:

- Derive closed-form expressions for the chorus delay modulation.
- Describe the exact finite-state machine for the Sigma-Delta DAC.
- Outline the UART sync protocol state machine.

Please review for accuracy before we proceed with detailed algorithm documentation.
