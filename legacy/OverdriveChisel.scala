package dsp

import chisel3._
import chisel3.util._

/**
  * Hardware implementation of the Overdrive audio effect in Chisel.
  * Uses 32-bit Q1.31 fixed-point arithmetic with a 16-segment Piecewise Linear (PWL)
  * approximation for soft-clipping saturation (x / (1 + |x|)).
  *
  * @param driveGain Drive amplification factor (default = 10)
  * @param brightnessFactor Pre-filter high-pass coefficient (default = 0.50)
  * @param asymmetricBias Asymmetric distortion bias for negative samples (default = 1.35)
  * @param levelTrim Output volume scaling factor (default = 0.35)
  */
class OverdriveChisel(
    val driveGain: Double = 10.0,
    val brightnessFactor: Double = 0.50,
    val asymmetricBias: Double = 1.35,
    val levelTrim: Double = 0.35
) extends Module {

  val io = IO(new AudioStreamIO(32))

  // 32 uniform segments over u in [0.0, 32.0] (step size = 1.0)
  private val numSegments = 32
  private val lutTable: Seq[BigInt] = (0 to numSegments).map { k =>
    val u = k.toDouble
    val y = u / (1.0 + u)
    FixedPointQ31.doubleToQ31BigInt(y)
  }

  // Chisel 33-element ROM Vector (extremely fast MUX tree in simulation & minimal FPGA area)
  private val lutROM = VecInit(lutTable.map(_.S(32.W)))

  // Compile-time fixed-point constants
  private val brightnessQ31 = FixedPointQ31.doubleToQ31BigInt(brightnessFactor).S(32.W)
  private val levelTrimQ31  = FixedPointQ31.doubleToQ31BigInt(levelTrim).S(32.W)

  // Pre-scaled gain multipliers in Q16.16 format for 64-bit product
  // Pos scale = driveGain * 65536 = 10.0 * 65536 = 655360
  // Neg scale = driveGain * asymmetricBias * 65536 = 13.5 * 65536 = 884736
  private val scalePosQ16 = BigInt(Math.round(driveGain * 65536.0)).S(40.W)
  private val scaleNegQ16 = BigInt(Math.round(driveGain * asymmetricBias * 65536.0)).S(40.W)

  // Filter state registers
  val prevInputReg = RegInit(0.S(32.W))
  val outSampleReg = RegInit(0.S(32.W))
  val outValidReg  = RegInit(false.B)

  // Step 1: High-Pass Pre-Filter: y_hp = sample - brightness * prevInput
  val hpTerm     = FixedPointQ31.multQ31(prevInputReg, brightnessQ31)
  val highPassed = FixedPointQ31.subQ31(io.sampleIn, hpTerm)

  // Step 2: Sign separation & magnitude calculation
  val isPositive = highPassed >= 0.S
  val hpAbs      = Mux(isPositive, highPassed, FixedPointQ31.subQ31(0.S, highPassed))

  // Select appropriate gain scale
  val scaleFactor = Mux(isPositive, scalePosQ16, scaleNegQ16)

  // hpAbs (Q1.31, 32-bit) * scaleFactor (Q16.16, 40-bit) => Q17.47 product
  val scaledWide = hpAbs * scaleFactor

  // Max value for u = 32.0 (index 32 = 32 * 2^47 = 2^52)
  val maxScaledWide = (BigInt(32) << 47).S
  val clampedWide   = Mux(scaledWide < 0.S, 0.S, Mux(scaledWide > maxScaledWide, maxScaledWide, scaledWide))

  // Extract 5-bit integer index (bits 51..47) and 32-bit non-negative fractional offset (bits 46..16)
  val lutIdx     = clampedWide(51, 47)
  val lutNextIdx = Mux(lutIdx >= 32.U, 32.U, lutIdx + 1.U)
  val lutFrac    = Cat(0.U(1.W), clampedWide(46, 16)).asSInt

  // Step 3: Uniform PWL Interpolation: y = y0 + frac * (y1 - y0)
  val y0     = lutROM(lutIdx)
  val y1     = lutROM(lutNextIdx)
  val deltaY = FixedPointQ31.subQ31(y1, y0)
  val interp = FixedPointQ31.multQ31(deltaY, lutFrac)
  val satMag = FixedPointQ31.addQ31(y0, interp)

  // Apply sign
  val saturatedSample = Mux(isPositive, satMag, FixedPointQ31.subQ31(0.S, satMag))

  // Step 4: Output Volume Scaling
  val finalOutput = FixedPointQ31.multQ31(saturatedSample, levelTrimQ31)

  when(io.sampleValid) {
    prevInputReg := io.sampleIn
    outSampleReg := finalOutput
    outValidReg  := true.B
  }.otherwise {
    outValidReg  := false.B
  }

  io.sampleOut := outSampleReg
  io.outValid  := outValidReg
}
