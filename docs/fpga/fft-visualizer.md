# FFT visualizer

`VisualizerTop` (`fpga/src/main/scala/dsp/visualizer/VisualizerTop.scala`) turns the audio stream into 8 band magnitudes for the LED matrix and UART telemetry.

Chain: `SampleBuffer` → `FftCore` → `FFTMagnitudeBinner` → `FFTTemporalTracker`.

## SampleBuffer — `SampleBuffer.scala`

Collects 1024 samples (top 12 bits of each 32-bit sample), then bursts them out to the FFT in order.

## FftCore — `FftCore.scala`

Blackbox wrapping `vsrc/r22sdf/R22SdfFFT1024.v`: a 1024-point radix-2² single-path delay-feedback (SDF) FFT, 12-bit data, 5 stages (M = 1024, 256, 64, 16, 4). Output is bit-reversed and scaled by 1/N (each butterfly divides by 2).

## FFTMagnitudeBinner — `FFTMagnitudeBinner.scala`

- Magnitude approximation, no multipliers: `|z| ≈ max(|re|,|im|) + 3/8 · min(|re|,|im|)`.
- Reverses the FFT's bit-reversal to recover natural bin order, then maps bins to 8 log-spaced bands (cutoffs in `VisualizerConfig`).
- Accumulates the sum of magnitudes per band and tracks the per-band peak. On each frame it outputs `mean + PeakBlend · (peak − mean)` (PeakBlend = 0.2).

## FFTTemporalTracker — `FFTTemporalTracker.scala`

Fast-attack / decay envelope per band: jumps up immediately when a band rises, decays exponentially otherwise (retention 0.55 per frame). Outputs 8 × 24-bit `catVolume`.

## VisualizerConfig — `VisualizerConfig.scala`

| Parameter | Value |
|-----------|-------|
| Sample rate | 48 kHz |
| FFT size | 1024 (46.875 Hz per bin) |
| Band cutoffs (Hz) | 140, 280, 560, 1125, 2250, 4500, 9000 |
| Max frequency | 16 kHz |
| Peak blend | 0.2 |
| Decay retention | 0.55 |
| LED refresh | 1 kHz |

Band sensitivity shifts and LED height thresholds also live here.
