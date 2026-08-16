package dsp

import chisel3._
import chisel3.util._

class FuzzChisel(
  val gain: Double = 4.0,
  val mix: Double = 0.9,
  val preGain: Double = 6.0
) extends Module {
  val io = IO(new AudioStreamIO(32))

  private val lutEntries = 512
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

  val rom = Module(new DualPortBramRom(lutEntries, 32, lutTable))
  rom.io.clock := clock

  val samplePipe = RegInit(0.S(32.W))
  val fracPipe   = RegInit(0.S(32.W))
  val validPipe  = RegInit(false.B)

  // 6x Pre-gain (4x + 2x = (sample<<2) + (sample<<1))
  val shifted4 = (io.sampleIn << 2).asSInt
  val shifted2 = (io.sampleIn << 1).asSInt
  val gainedSum = shifted4 +& shifted2
  val gained = FixedPointQ31.saturateSInt(gainedSum, 32)

  val gainedUnsigned = (gained + 0x80000000L.S(33.W)).asUInt
  val lutIdx         = (gainedUnsigned >> 23)(8, 0)
  val lutNextIdx     = Mux(lutIdx === (lutEntries - 1).U, lutIdx, (lutIdx + 1.U)(8, 0))
  val fracBits       = gainedUnsigned(22, 0)
  val fracQ31        = Cat(0.U(1.W), fracBits, 0.U(8.W)).asSInt

  rom.io.addrA := lutIdx
  rom.io.addrB := lutNextIdx

  when(io.sampleValid) {
    samplePipe := io.sampleIn
    fracPipe   := fracQ31
    validPipe  := true.B
  }.otherwise {
    validPipe  := false.B
  }

  val romDataA = rom.io.dataA
  val romDataB = rom.io.dataB

  val delta    = FixedPointQ31.subQ31(romDataB, romDataA)
  val interped = FixedPointQ31.addQ31(romDataA, FixedPointQ31.multQ31(delta, fracPipe))

  val mixQ31         = FixedPointQ31.doubleToQ31BigInt(mix).S(32.W)
  val oneMinusMixQ31 = FixedPointQ31.doubleToQ31BigInt(1.0 - mix).S(32.W)

  val dryTerm  = FixedPointQ31.multQ31(oneMinusMixQ31, samplePipe)
  val wetTerm  = FixedPointQ31.multQ31(mixQ31, interped)
  val finalOut = FixedPointQ31.addQ31(dryTerm, wetTerm)

  val outSampleReg = RegInit(0.S(32.W))
  val outValidReg  = RegInit(false.B)

  when(validPipe) {
    outSampleReg := finalOut
    outValidReg  := true.B
  }.otherwise {
    outValidReg  := false.B
  }

  io.sampleOut := outSampleReg
  io.outValid  := outValidReg
}
