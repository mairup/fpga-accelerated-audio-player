package dsp

import chisel3._
import chisel3.util._

class SaturatingOverdriveChisel(
  val gain: Double = 3,
  val threshold: Double = 0.03
) extends Module {
  val io = IO(new AudioStreamIO(32))

  private val gainQ16 = BigInt(Math.round(gain * 65536.0)).S(40.W)
  private val thresholdQ31 = FixedPointQ31.doubleToQ31BigInt(threshold).S(32.W)

  val sampleInWide = (io.sampleIn * gainQ16) >> 16
  val gainedSignal = FixedPointQ31.saturateSInt(sampleInWide, 32)

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
