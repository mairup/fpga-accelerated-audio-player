package dsp

import chisel3._
import chisel3.util._

class Overdrive(
  val gain: Double = 7.0,
  val threshold: Double = 0.2
) extends Module {
  val io = IO(new AudioStreamIO(32))

  private val gainQ16 = BigInt(Math.round(gain * 65536.0))
  private val thresholdQ31 = FixedPointQ31.doubleToQ31BigInt(threshold).S(32.W)

  private def multSIntByBigInt(x: SInt, c: BigInt): SInt = {
    if (c == 0) 0.S
    else if (c < 0) -multSIntByBigInt(x, -c)
    else {
      val shifts = c.toString(2).reverse.zipWithIndex.collect { case ('1', i) => i }
      shifts.map(i => x << i).reduce(_ + _)
    }
  }

  val sampleInWide = multSIntByBigInt(io.sampleIn, gainQ16) >> 16
  val gainedSignal = FixedPointQ31.saturateSInt(sampleInWide.asSInt, 32)

  val isPositive = gainedSignal >= 0.S
  val absGainedSignal = Mux(isPositive, gainedSignal, FixedPointQ31.subQ31(0.S, gainedSignal))

  val exceedsThreshold = absGainedSignal > thresholdQ31
  val thresholdValue = Mux(isPositive, thresholdQ31, FixedPointQ31.subQ31(0.S, thresholdQ31))

  val saturatedSignal = Mux(exceedsThreshold, thresholdValue, gainedSignal)

  val outSampleReg = RegInit(0.S(32.W))
  val outValidReg  = RegInit(false.B)

  when(io.sampleValid) {
    outSampleReg := saturatedSignal
    outValidReg  := true.B
  }.otherwise {
    outValidReg  := false.B
  }

  io.sampleOut := outSampleReg
  io.outValid  := outValidReg
}
