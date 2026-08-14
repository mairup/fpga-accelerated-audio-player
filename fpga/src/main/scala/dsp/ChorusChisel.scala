package dsp

import chisel3._
import chisel3.util._

class ChorusChisel(
    val rateHz: Double = 1.2,
    val depthMs: Double = 2.5,
    val centerDelayMs: Double = 7.0,
    val mix: Double = 0.5,
    val sampleRate: Double = 44100.0
) extends Module {

  val io = IO(new AudioStreamIO(32))

  private val bufferSize = 32
  val delayBuffer = RegInit(VecInit(Seq.fill(bufferSize)(0.S(32.W))))

  private val sineEntries = 128
  private val sineTable: Seq[BigInt] = (0 until sineEntries).map { i =>
    val rad = 2.0 * Math.PI * i.toDouble / sineEntries.toDouble
    FixedPointQ31.doubleToQ31BigInt(Math.sin(rad))
  }
  private val sineROM = VecInit(sineTable.map(_.S(32.W)))

  private val phaseStepVal = BigInt(Math.round(rateHz * (1L << 24).toDouble / sampleRate))
  private val phaseStep = phaseStepVal.U(24.W)

  private val centerDelaySamples = centerDelayMs * (sampleRate / 1000.0)
  private val depthSamples       = depthMs * (sampleRate / 1000.0)

  private val centerDelayQ16 = BigInt(Math.round(centerDelaySamples * 65536.0)).S(32.W)
  private val depthQ16       = BigInt(Math.round(depthSamples * 65536.0)).S(32.W)

  private val coef070 = FixedPointQ31.doubleToQ31BigInt(0.70).S(32.W)
  private val coef030 = FixedPointQ31.doubleToQ31BigInt(0.30).S(32.W)

  private val mixQ31        = FixedPointQ31.doubleToQ31BigInt(mix).S(32.W)
  private val oneMinusMixQ31 = FixedPointQ31.doubleToQ31BigInt(1.0 - mix).S(32.W)

  val writePtrReg  = RegInit(0.U(5.W))
  val lfoPhaseReg  = RegInit(0.U(24.W))
  val prevWetReg   = RegInit(0.S(32.W))
  val outSampleReg = RegInit(0.S(32.W))
  val outValidReg  = RegInit(false.B)

  val lfoIdx     = lfoPhaseReg(23, 17)
  val lfoNextIdx = (lfoIdx + 1.U)(6, 0)
  val lfoFrac    = Cat(0.U(1.W), lfoPhaseReg(16, 2)).asSInt

  val lfoY0     = sineROM(lfoIdx)
  val lfoY1     = sineROM(lfoNextIdx)
  val lfoDelta  = FixedPointQ31.subQ31(lfoY1, lfoY0)
  val lfoVal    = FixedPointQ31.addQ31(lfoY0, FixedPointQ31.multQ31(lfoDelta, lfoFrac))

  val modDelayQ16     = FixedPointQ31.multQ31(depthQ16, lfoVal)
  val delaySamplesQ16 = FixedPointQ31.addQ31(centerDelayQ16, modDelayQ16)

  val writePtrQ16 = Cat(writePtrReg, 0.U(16.W)).asSInt
  val readPtrQ16  = FixedPointQ31.subQ31(writePtrQ16, delaySamplesQ16)

  val floorIdx = (readPtrQ16 >> 16)(4, 0)
  val nextIdx  = (floorIdx + 1.U)(4, 0)

  val fracQ31 = Cat(0.U(1.W), readPtrQ16(15, 1)).asSInt

  val s1 = delayBuffer(floorIdx)
  val s2 = delayBuffer(nextIdx)

  val deltaS = FixedPointQ31.subQ31(s2, s1)
  val rawWet = FixedPointQ31.addQ31(s1, FixedPointQ31.multQ31(deltaS, fracQ31))

  val term070 = FixedPointQ31.multQ31(coef070, rawWet)
  val term030 = FixedPointQ31.multQ31(coef030, prevWetReg)
  val warmWet = FixedPointQ31.addQ31(term070, term030)

  val dryTerm  = FixedPointQ31.multQ31(oneMinusMixQ31, io.sampleIn)
  val wetTerm  = FixedPointQ31.multQ31(mixQ31, warmWet)
  val finalOut = FixedPointQ31.addQ31(dryTerm, wetTerm)

  when(io.sampleValid) {
    delayBuffer(writePtrReg) := io.sampleIn
    writePtrReg := (writePtrReg + 1.U)(4, 0)
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
