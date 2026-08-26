package dsp.visualizer

import chisel3._
import chisel3.util._

/** Centralized configuration for the Audio Spectrum Visualizer & 8x8 LED Matrix Display.
 *
 *  Modify parameters in this file to tweak frequency cutoffs, sensitivity shifts,
 *  and LED height thresholds across the entire DSP and display pipeline.
 */
object VisualizerConfig {

  // =========================================================================
  // 1. Audio & Timing Settings
  // =========================================================================
  val SampleRateHz:   Int = 48_000
  val FftSize:        Int = 1024
  val ClockFreqHz:    Int = 100_000_000
  val FrameRefreshHz: Int = 1000 // Full matrix refresh (1 kHz -> 8 kHz row scan)
  val Orientation:    Int = 0    // 0 = upright, 1 = 90 deg CW, 2 = 180 deg, 3 = 270 deg CW

  val BinResolutionHz: Double = SampleRateHz.toDouble / FftSize // 46.875 Hz per bin

  // =========================================================================
  // 2. Frequency Band Boundaries (in Hz)
  // =========================================================================
  // 7 cutoff frequencies defining the upper limits of the first 7 bands (8th band covers the rest up to Nyquist 24 kHz).
  //   - Band 0: 0 Hz to 140 Hz (Sub-bass)
  //   - Band 1: 140 Hz to 280 Hz (Bass)
  //   - Band 2: 280 Hz to 560 Hz (Low-mid)
  //   - Band 3: 560 Hz to 1125 Hz (Mid)
  //   - Band 4: 1125 Hz to 2250 Hz (Upper-mid)
  //   - Band 5: 2250 Hz to 4500 Hz (Presence)
  //   - Band 6: 4500 Hz to 9000 Hz (Brilliance)
  //   - Band 7: 9000 Hz to 24000 Hz (Air)
  val BandCutoffsHz: Seq[Int] = Seq(140, 280, 560, 1125, 2250, 4500, 9000)
  val MaxFreqHz:     Int      = 16_000

  // Compile-time conversion from Hz cutoffs to FFT bin index cutoffs:
  // e.g. [3, 6, 12, 24, 48, 96, 192]
  val BandCutoffBins: Seq[Int] = BandCutoffsHz.map(hz => math.round(hz / BinResolutionHz).toInt.max(1))
  val MaxFreqBin:     Int      = math.round(MaxFreqHz / BinResolutionHz).toInt.min(FftSize / 2)

  // Number of FFT bins accumulated into each of the 8 frequency bands:
  val BandBinCounts: Seq[Int] = {
    val boundaries = Seq(0) ++ BandCutoffBins ++ Seq(MaxFreqBin)
    (0 until 8).map(i => (boundaries(i + 1) - boundaries(i)).max(1))
  }

  // Precomputed 16-bit fixed-point multipliers for exact compile-time division: round(65536 / count)
  val BandDivMultipliers: Seq[Int] = BandBinCounts.map(count => math.round(65536.0 / count).toInt)

  // =========================================================================
  // 2b. Peak-Weighted Blend Factor (0.0 = pure mean, 1.0 = pure peak)
  // =========================================================================
  // Fine fractional adjustment of how much the per-band peak is blended into the mean:
  //   0.00 -> 100% mean,   0% peak (pure average energy)
  //   0.50 ->  50% mean,  50% peak (balanced midpoint)
  //   0.75 ->  25% mean,  75% peak (recommended for punchier transients)
  //   0.85 ->  15% mean,  85% peak (very sharp, transient-focused)
  //   1.00 ->   0% mean, 100% peak (pure peak)
  val PeakBlendFactor: Double = 0.2

  // 8-bit fixed-point multiplier (0 to 256): round(PeakBlendFactor * 256)
  val PeakBlendMult: Int = math.round(PeakBlendFactor * 256.0).toInt.max(0).min(256)

  // =========================================================================
  // 2c. Fall / Decay Retention Factor (0.0 = instant drop, 1.0 = no decay)
  // =========================================================================
  // Percentage of energy retained from the previous frame (at ~46.88 Hz frame rate):
  //   0.20 -> retains 20% per frame (very fast 80% drop per frame)
  //   0.35 -> retains 35% per frame (fast 65% drop per frame)
  //   0.50 -> retains 50% per frame (50% drop per frame, equivalent to old >> 1)
  //   0.75 -> retains 75% per frame (25% drop per frame)
  //   0.85 -> retains 85% per frame (15% drop per frame, smooth lingering VU fall)
  val DecayRetention: Double = 0.55

  // 8-bit fixed-point multiplier (0 to 256): round(DecayRetention * 256)
  val DecayMult: Int = math.round(DecayRetention * 256.0).toInt.max(0).min(256)

  // =========================================================================
  // 3. Sensitivity / Attenuation (Bit Shift per Band)
  // =========================================================================
  // Bit shift applied to raw accumulated FFT magnitude before height quantization.
  // Positive shift (e.g. +1, +2, +3): Attenuates (>> 1 = /2, >> 2 = /4, >> 3 = /8).
  // Zero shift (0): Passthrough (>> 0 = /1).
  // Negative shift (e.g. -1, -2, -3): Boosts / amplifies (<< 1 = *2, << 2 = *4, << 3 = *8).
  val BandShifts: Seq[Int] = Seq(
    4, // Band 0: Sub-bass (>> 3 = /8, attenuates high acoustic sub-bass energy)
    3, // Band 1: Bass (>> 1 = /2)
    2, // Band 2: Low-mid (>> 1 = /2)
    1, // Band 3: Mid (>> 2 = /4)
    1, // Band 4: Upper-mid (>> 2 = /4)
    1, // Band 5: Presence (>> 1 = /2)
    2, // Band 6: Brilliance (>> 1 = /2)
    2  // Band 7: Air (>> 3 = /8, normalizes wide bin accumulation)
  )

  // =========================================================================
  // 4. Height Quantization Thresholds Curve (Jumpiness & Dynamic Range)
  // =========================================================================
  // BaseThreshold: Raw/normalized magnitude needed to light the 1st LED (Row 0 / bottom).
  // GrowthFactor:  Multiplier between consecutive LED heights:
  //                threshold(i) = BaseThreshold * (GrowthFactor ^ i)
  //
  //   - Lower GrowthFactor (e.g. 1.4 - 1.7): Jumpier / more responsive, bars bounce higher easily.
  //   - Higher GrowthFactor (e.g. 2.0 - 2.5): Steeper dynamic range, wider volume separation between quiet and loud peaks.
  val BaseThreshold: Double = 1.9
  val GrowthFactor:  Double = 1.85

  // Compile-time calculation of the 8 height thresholds (for 1 to 8 LEDs)
  // With 4.0 and 1.6, this produces: Seq(4, 6, 10, 16, 26, 42, 67, 107)
  val HeightThresholds: Seq[Int] = (0 until 8).map { i =>
    math.round(BaseThreshold * math.pow(GrowthFactor, i)).toInt.max(1)
  }

  /** Converts a 24-bit smoothed band magnitude to a column height from 0 to 8 LEDs. */
  def quantizeToLevel(magnitude: UInt, bandIdx: Int): UInt = {
    val shift = BandShifts.lift(bandIdx).getOrElse(0)
    // Support positive shifts (divide/attenuate), 0 (passthrough), and negative shifts (multiply/boost)
    val norm  = if (shift >= 0) magnitude >> shift.U else magnitude << (-shift).U

    Mux(norm >= HeightThresholds(7).U, 8.U,
    Mux(norm >= HeightThresholds(6).U, 7.U,
    Mux(norm >= HeightThresholds(5).U, 6.U,
    Mux(norm >= HeightThresholds(4).U, 5.U,
    Mux(norm >= HeightThresholds(3).U, 4.U,
    Mux(norm >= HeightThresholds(2).U, 3.U,
    Mux(norm >= HeightThresholds(1).U, 2.U,
    Mux(norm >= HeightThresholds(0).U, 1.U, 0.U))))))))
  }

  /** Converts a 24-bit smoothed band magnitude to an ASCII level ('1' to '8') for UART telemetry. */
  def quantizeToAscii(magnitude: UInt, bandIdx: Int): UInt = {
    val level = quantizeToLevel(magnitude, bandIdx)
    val displayLevel = Mux(level === 0.U, 0.U, level - 1.U)
    displayLevel + '1'.U(8.W)
  }
}
