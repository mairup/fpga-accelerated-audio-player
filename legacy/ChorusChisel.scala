package dsp

import chisel3._
import chisel3.util._

/**
  * Hardware implementation of the Chorus audio effect in Chisel,
  * modeled after the classic BOSS CE-2 analog chorus pedal.
  * Uses 32-bit Q1.31 fixed-point signed arithmetic.
  *
  * @param rateHz LFO modulation rate in Hz (default = 1.2 Hz)
  * @param depthMs Modulation depth in ms (default = 2.5 ms)
  * @param centerDelayMs BBD center delay in ms (default = 7.0 ms)
  * @param mix Dry/Wet blend (default = 0.5 for 50% dry, 50% wet)
  * @param sampleRate Audio sampling rate in Hz (default = 44100.0)
  */
class ChorusChisel(
    val rateHz: Double = 1.2,
    val depthMs: Double = 2.5,
    val centerDelayMs: Double = 7.0,
    val mix: Double = 0.5,
    val sampleRate: Double = 44100.0
) extends Module {

  val io = IO(new AudioStreamIO(32))

  private val bufferSize = 2048 // 2048 samples (~46.4 ms buffer at 44.1 kHz)
  private val delayBuffer = Mem(bufferSize, SInt(32.W))

  // Pre-computed 32-entry Sine ROM in Q1.31 format with linear interpolation
  private val sineEntries = 32
  private val sineTable: Seq[BigInt] = (0 until sineEntries).map { i =>
    val rad = 2.0 * Math.PI * i.toDouble / sineEntries.toDouble
    FixedPointQ31.doubleToQ31BigInt(Math.sin(rad))
  }
  private val sineROM = VecInit(sineTable.map(_.S(32.W)))

  // Phase accumulator step for 24-bit phase counter: step = rateHz * 2^24 / sampleRate
  private val phaseStepVal = BigInt(Math.round(rateHz * (1L << 24).toDouble / sampleRate))
  private val phaseStep = phaseStepVal.U(24.W)

  // Delay constants in Q16.16 format
  private val centerDelaySamples = centerDelayMs * (sampleRate / 1000.0)
  private val depthSamples       = depthMs * (sampleRate / 1000.0)

  private val centerDelayQ16 = BigInt(Math.round(centerDelaySamples * 65536.0)).S(32.W)
  private val depthQ16       = BigInt(Math.round(depthSamples * 65536.0)).S(32.W)

  // BBD Warmth filter coefficients (Q1.31)
  private val coef070 = FixedPointQ31.doubleToQ31BigInt(0.70).S(32.W)
  private val coef030 = FixedPointQ31.doubleToQ31BigInt(0.30).S(32.W)

  // Dry/Wet Mix coefficients (Q1.31)
  private val mixQ31        = FixedPointQ31.doubleToQ31BigInt(mix).S(32.W)
  private val oneMinusMixQ31 = FixedPointQ31.doubleToQ31BigInt(1.0 - mix).S(32.W)

  // Registers
  val writePtrReg  = RegInit(0.U(11.W))
  val lfoPhaseReg  = RegInit(0.U(24.W))
  val prevWetReg   = RegInit(0.S(32.W))
  val outSampleReg = RegInit(0.S(32.W))
  val outValidReg  = RegInit(false.B)

  // 1. Advance LFO phase with 32-entry Sine ROM & Linear Interpolation
  val lfoIdx     = lfoPhaseReg(23, 19)              // 5-bit ROM index
  val lfoNextIdx = (lfoIdx + 1.U)(4, 0)
  val lfoFrac    = Cat(0.U(1.W), lfoPhaseReg(18, 4)).asSInt

  val lfoY0     = sineROM(lfoIdx)
  val lfoY1     = sineROM(lfoNextIdx)
  val lfoDelta  = FixedPointQ31.subQ31(lfoY1, lfoY0)
  val lfoVal    = FixedPointQ31.addQ31(lfoY0, FixedPointQ31.multQ31(lfoDelta, lfoFrac))

  // 2. Compute dynamic modulated delay offset in Q16.16 format
  // modDelayQ16 = depthQ16 * lfoVal (Q16.16 * Q1.31 => Q16.16 after multQ31)
  val modDelayQ16     = FixedPointQ31.multQ31(depthQ16, lfoVal)
  val delaySamplesQ16 = FixedPointQ31.addQ31(centerDelayQ16, modDelayQ16)

  // 3. Calculate Read Pointer in Q16.16 format
  val writePtrQ16 = Cat(writePtrReg, 0.U(16.W)).asSInt
  val readPtrQ16  = FixedPointQ31.subQ31(writePtrQ16, delaySamplesQ16)

  val floorIdx = (readPtrQ16 >> 16)(10, 0)
  val nextIdx  = (floorIdx + 1.U)(10, 0)

  // 16-bit fractional offset zero-extended into 32-bit Q1.31 format
  val fracQ31 = Cat(0.U(1.W), readPtrQ16(15, 1)).asSInt

  // 4. Memory read & 2-Point Fractional Linear Interpolation
  val s1 = delayBuffer.read(floorIdx)
  val s2 = delayBuffer.read(nextIdx)

  val deltaS = FixedPointQ31.subQ31(s2, s1)
  val rawWet = FixedPointQ31.addQ31(s1, FixedPointQ31.multQ31(deltaS, fracQ31))

  // 5. Analog BBD Warmth Filter (0.70 * rawWet + 0.30 * prevWet)
  val term070 = FixedPointQ31.multQ31(coef070, rawWet)
  val term030 = FixedPointQ31.multQ31(coef030, prevWetReg)
  val warmWet = FixedPointQ31.addQ31(term070, term030)

  // 6. Dry/Wet Mix
  val dryTerm  = FixedPointQ31.multQ31(oneMinusMixQ31, io.sampleIn)
  val wetTerm  = FixedPointQ31.multQ31(mixQ31, warmWet)
  val finalOut = FixedPointQ31.addQ31(dryTerm, wetTerm)

  when(io.sampleValid) {
    delayBuffer.write(writePtrReg, io.sampleIn)
    writePtrReg := (writePtrReg + 1.U)(10, 0)
    lfoPhaseReg := lfoPhaseReg + phaseStep
    prevWetReg  := warmWet
    outSampleReg := finalOut
    outValidReg  := true.B
  }.otherwise {
    outValidReg := false.B
  }

  io.sampleOut := outSampleReg
  io.outValid  := outValidReg
}
