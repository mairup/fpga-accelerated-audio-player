package dsp

import chisel3._
import chisel3.util._

class FuzzChisel(val gain: Double = 4.0, val mix: Double = 0.9) extends Module {
  val io = IO(new AudioStreamIO(32))

  private val lutEntries = 128
  private val lutTable: Seq[BigInt] = (0 until lutEntries).map { i =>
    val x = -1.0 + 2.0 * i.toDouble / (lutEntries - 1).toDouble
    val gainX = gain * x
    val saturated = if (gainX >= 0) {
      1.0 - Math.exp(-2.5 * gainX)
    } else {
      -(1.0 - Math.exp(1.5 * gainX))
    }
    val clamped = Math.max(-1.0, Math.min(1.0, saturated))
    FixedPointQ31.doubleToQ31BigInt(clamped)
  }
  private val lutROM = VecInit(lutTable.map(_.S(32.W)))

  val outSampleReg = RegInit(0.S(32.W))
  val outValidReg  = RegInit(false.B)

  val sampleUnsigned = (io.sampleIn + 0x80000000L.S(33.W)).asUInt
  val lutIdx         = (sampleUnsigned >> 25)(6, 0)
  val satSample      = lutROM(lutIdx)

  val mixQ31         = FixedPointQ31.doubleToQ31BigInt(mix).S(32.W)
  val oneMinusMixQ31 = FixedPointQ31.doubleToQ31BigInt(1.0 - mix).S(32.W)

  val dryTerm  = FixedPointQ31.multQ31(oneMinusMixQ31, io.sampleIn)
  val wetTerm  = FixedPointQ31.multQ31(mixQ31, satSample)
  val finalOut = FixedPointQ31.addQ31(dryTerm, wetTerm)

  when(io.sampleValid) {
    outSampleReg := finalOut
    outValidReg  := true.B
  }.otherwise {
    outValidReg := false.B
  }

  io.sampleOut := outSampleReg
  io.outValid  := outValidReg
}
