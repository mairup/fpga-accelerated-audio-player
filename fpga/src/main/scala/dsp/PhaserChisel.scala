package dsp

import chisel3._
import chisel3.util._

class PhaserChisel(
  val rateHz:     Double = 0.5,
  val minFreqHz:  Double = 350.0,
  val maxFreqHz:  Double = 1800.0,
  val feedback:   Double = 0.15,
  val mix:        Double = 0.40,
  val sampleRate: Double = 48000.0
) extends Module {
  val io = IO(new AudioStreamIO(32))

  private val romEntries = 512
  private val coeffTable: Seq[BigInt] = (0 until romEntries).map { i =>
    val phase   = 2.0 * Math.PI * i.toDouble / romEntries.toDouble
    val lfoNorm = (Math.sin(phase) + 1.0) / 2.0
    val freq    = minFreqHz + lfoNorm * (maxFreqHz - minFreqHz)
    val t       = Math.tan(Math.PI * freq / sampleRate)
    val a       = (t - 1.0) / (t + 1.0)
    FixedPointQ31.doubleToQ31BigInt(a)
  }

  val rom = Module(new DualPortBramRom(romEntries, 32, coeffTable))
  rom.io.clock := clock

  private val phaseStepVal = BigInt(Math.round(rateHz * (1L << 24).toDouble / sampleRate))
  private val phaseStep    = phaseStepVal.U(24.W)

  val lfoPhaseReg = RegInit(0.U(24.W))

  val romIdx     = lfoPhaseReg(23, 15)
  val romNextIdx = (romIdx +& 1.U)(8, 0)
  val romFrac    = Cat(0.U(1.W), lfoPhaseReg(14, 0), 0.U(16.W)).asSInt

  rom.io.addrA := romIdx
  rom.io.addrB := romNextIdx

  val samplePipe = RegInit(0.S(32.W))
  val fracPipe   = RegInit(0.S(32.W))
  val validPipe  = RegInit(false.B)

  when(io.sampleValid) {
    samplePipe := io.sampleIn
    fracPipe   := romFrac
    validPipe  := true.B
  }.otherwise {
    validPipe  := false.B
  }

  val aY0        = rom.io.dataA
  val aY1        = rom.io.dataB
  val aDelta     = FixedPointQ31.subQ31(aY1, aY0)
  val aCoeffWire = FixedPointQ31.addQ31(aY0, FixedPointQ31.multQ31(aDelta, fracPipe))

  private val feedbackQ31    = FixedPointQ31.doubleToQ31BigInt(feedback).S(32.W)
  private val mixQ31         = FixedPointQ31.doubleToQ31BigInt(mix).S(32.W)
  private val oneMinusMixQ31 = FixedPointQ31.doubleToQ31BigInt(1.0 - mix).S(32.W)

  val xPrev = RegInit(VecInit(Seq.fill(4)(0.S(32.W))))
  val yPrev = RegInit(VecInit(Seq.fill(4)(0.S(32.W))))

  val feedbackReg  = RegInit(0.S(32.W))
  val outSampleReg = RegInit(0.S(32.W))
  val outValidReg  = RegInit(false.B)

  def apfCompute(x: SInt, a: SInt, xP: SInt, yP: SInt): SInt = {
    val ax  = FixedPointQ31.multQ31(a, x)
    val ayP = FixedPointQ31.multQ31(a, yP)
    val sum = FixedPointQ31.addQ31(ax, xP)
    FixedPointQ31.subQ31(sum, ayP)
  }

  when(validPipe) {
    val fbScaled    = FixedPointQ31.multQ31(feedbackReg, feedbackQ31)
    val inputWithFb = FixedPointQ31.addQ31(samplePipe, fbScaled)

    val st0 = apfCompute(inputWithFb, aCoeffWire, xPrev(0), yPrev(0))
    val st1 = apfCompute(st0,         aCoeffWire, xPrev(1), yPrev(1))
    val st2 = apfCompute(st1,         aCoeffWire, xPrev(2), yPrev(2))
    val st3 = apfCompute(st2,         aCoeffWire, xPrev(3), yPrev(3))

    xPrev(0) := inputWithFb
    yPrev(0) := st0

    xPrev(1) := st0
    yPrev(1) := st1

    xPrev(2) := st1
    yPrev(2) := st2

    xPrev(3) := st2
    yPrev(3) := st3

    feedbackReg := st3

    val dryTerm  = FixedPointQ31.multQ31(oneMinusMixQ31, samplePipe)
    val wetTerm  = FixedPointQ31.multQ31(mixQ31, st3)
    val finalOut = FixedPointQ31.addQ31(dryTerm, wetTerm)

    lfoPhaseReg  := lfoPhaseReg + phaseStep
    outSampleReg := finalOut
    outValidReg  := true.B
  }.otherwise {
    outValidReg := false.B
  }

  io.sampleOut := outSampleReg
  io.outValid  := outValidReg
}
