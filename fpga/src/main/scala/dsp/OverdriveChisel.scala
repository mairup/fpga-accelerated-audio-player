package dsp

import chisel3._
import chisel3.util._

class OverdriveChisel(
  val driveGain: Double = 8.0,
  val brightnessFactor: Double = 0.50,
  val asymmetricBias: Double = 1.35,
  val levelTrim: Double = 0.35
) extends Module {
  val io = IO(new AudioStreamIO(32))

  private val numSegments = 32
  private val lutTable: Seq[BigInt] = (0 to numSegments).map { k =>
    val u = k.toDouble
    val y = u / (1.0 + u)
    FixedPointQ31.doubleToQ31BigInt(y)
  }

  val rom = Module(new DualPortBramRom(numSegments + 1, 32, lutTable))
  rom.io.clock := clock

  private val brightnessQ31 = FixedPointQ31.doubleToQ31BigInt(brightnessFactor).S(32.W)
  private val levelTrimQ31  = FixedPointQ31.doubleToQ31BigInt(levelTrim).S(32.W)

  private val scalePosQ16 = BigInt(Math.round(driveGain * 65536.0)).S(40.W)
  private val scaleNegQ16 = BigInt(Math.round(driveGain * asymmetricBias * 65536.0)).S(40.W)

  val prevInputReg = RegInit(0.S(32.W))

  val fracPipe  = RegInit(0.S(32.W))
  val signPipe  = RegInit(false.B)
  val validPipe = RegInit(false.B)

  val outSampleReg = RegInit(0.S(32.W))
  val outValidReg  = RegInit(false.B)

  val hpTerm     = FixedPointQ31.multQ31(prevInputReg, brightnessQ31)
  val highPassed = FixedPointQ31.subQ31(io.sampleIn, hpTerm)

  val isPositive  = highPassed >= 0.S
  val hpAbs       = Mux(isPositive, highPassed, FixedPointQ31.subQ31(0.S, highPassed))
  val scaleFactor = Mux(isPositive, scalePosQ16, scaleNegQ16)

  val scaledWide = hpAbs * scaleFactor

  val maxScaledWide = (BigInt(numSegments) << 47).S
  val clampedWide   = Mux(scaledWide < 0.S, 0.S, Mux(scaledWide > maxScaledWide, maxScaledWide, scaledWide))

  val lutIdx6    = clampedWide(51, 47).pad(6)
  val lutNextIdx = Mux(lutIdx6 >= numSegments.U, numSegments.U(6.W), lutIdx6 + 1.U)
  val lutFrac    = Cat(0.U(1.W), clampedWide(46, 16)).asSInt

  rom.io.addrA := lutIdx6
  rom.io.addrB := lutNextIdx

  when(io.sampleValid) {
    prevInputReg := io.sampleIn
    fracPipe     := lutFrac
    signPipe     := isPositive
    validPipe    := true.B
  }.otherwise {
    validPipe := false.B
  }

  val y0        = rom.io.dataA
  val y1        = rom.io.dataB
  val interp    = FixedPointQ31.addQ31(y0, FixedPointQ31.multQ31(FixedPointQ31.subQ31(y1, y0), fracPipe))
  val saturated = Mux(signPipe, interp, FixedPointQ31.subQ31(0.S, interp))
  val finalOut  = FixedPointQ31.multQ31(saturated, levelTrimQ31)

  when(validPipe) {
    outSampleReg := finalOut
    outValidReg  := true.B
  }.otherwise {
    outValidReg := false.B
  }

  io.sampleOut := outSampleReg
  io.outValid  := outValidReg
}
