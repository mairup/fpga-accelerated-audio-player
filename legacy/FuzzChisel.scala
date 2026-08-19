package dsp

import chisel3._
import chisel3.util._

/**
  * Hardware implementation of the Fuzz audio effect module in Chisel.
  * Uses 32-bit Q1.31 fixed-point signed arithmetic.
  *
  * @param fuzzGain Pre-gain amplification factor (integer multiplier, default = 50)
  * @param posThreshold Upper hard clipping threshold in range (0.0, 1.0] (default = 0.5)
  * @param negThreshold Lower hard clipping threshold (asymmetry) in range (0.0, 1.0] (default = 0.4)
  * @param toneFactor IIR Low-Pass filter coefficient (default = 0.60)
  * @param levelTrim Output volume scaling factor (default = 0.25)
  */
class FuzzChisel(
    val fuzzGain: Int = 50,
    val posThreshold: Double = 0.5,
    val negThreshold: Double = 0.4,
    val toneFactor: Double = 0.60,
    val levelTrim: Double = 0.25
) extends Module {

  val io = IO(new AudioStreamIO(32))

  // Compile-time fixed-point constants (Q1.31)
  private val posThreshQ31 = FixedPointQ31.doubleToQ31BigInt(posThreshold).S(32.W)
  private val negThreshQ31 = FixedPointQ31.doubleToQ31BigInt(-negThreshold).S(32.W)
  private val toneQ31      = FixedPointQ31.doubleToQ31BigInt(toneFactor).S(32.W)
  private val oneMinusToneQ31 = FixedPointQ31.doubleToQ31BigInt(1.0 - toneFactor).S(32.W)
  private val levelTrimQ31 = FixedPointQ31.doubleToQ31BigInt(levelTrim).S(32.W)

  // Filter state register
  val prevOutputReg = RegInit(0.S(32.W))
  val outSampleReg  = RegInit(0.S(32.W))
  val outValidReg   = RegInit(false.B)

  // Step 1: Pre-Gain Amplification (64-bit wide product)
  val amplifiedWide = io.sampleIn * fuzzGain.S

  // Step 2: Hard Asymmetric Clipping
  val clipped = Wire(SInt(32.W))
  when(amplifiedWide > posThreshQ31) {
    clipped := posThreshQ31
  }.elsewhen(amplifiedWide < negThreshQ31) {
    clipped := negThreshQ31
  }.otherwise {
    clipped := FixedPointQ31.saturateSInt(amplifiedWide, 32)
  }

  // Step 3: Low-Pass IIR Tone Filter
  val term1 = FixedPointQ31.multQ31(clipped, oneMinusToneQ31)
  val term2 = FixedPointQ31.multQ31(prevOutputReg, toneQ31)
  val filtered = FixedPointQ31.addQ31(term1, term2)

  // Step 4: Output Level Scaling
  val finalOutput = FixedPointQ31.multQ31(filtered, levelTrimQ31)

  when(io.sampleValid) {
    prevOutputReg := filtered
    outSampleReg  := finalOutput
    outValidReg   := true.B
  }.otherwise {
    outValidReg   := false.B
  }

  io.sampleOut := outSampleReg
  io.outValid  := outValidReg
}
