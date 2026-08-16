package dsp

import chisel3._
import chisel3.util._

class ChorusChisel(
    val rateHz: Double = 1.2,
    val depthMs: Double = 4.0,
    val centerDelayMs: Double = 10.0,
    val mix: Double = 0.5,
    val sampleRate: Double = 48000.0
) extends Module {

  val io = IO(new AudioStreamIO(32))

  private val delayBufSize = 1024
  private val delayBufAddrW = log2Ceil(delayBufSize)

  // 1024-sample hardware BRAM delay line (RAMB36E1)
  val ram = Module(new DualPortBramRam(delayBufSize, 32))
  ram.io.clock := clock

  private val sineEntries = 512
  private val sineTable: Seq[BigInt] = (0 until sineEntries).map { i =>
    val rad = 2.0 * Math.PI * i.toDouble / sineEntries.toDouble
    FixedPointQ31.doubleToQ31BigInt(Math.sin(rad))
  }

  // 512-entry hardware BRAM sine ROM (RAMB18E1)
  val sineRom = Module(new DualPortBramRom(sineEntries, 32, sineTable))
  sineRom.io.clock := clock

  private val phaseStepVal = BigInt(Math.round(rateHz * (1L << 24).toDouble / sampleRate))
  private val phaseStep = phaseStepVal.U(24.W)

  private val centerDelaySamples = centerDelayMs * (sampleRate / 1000.0)
  private val depthSamples       = depthMs * (sampleRate / 1000.0)

  private val centerDelayQ16 = BigInt(Math.round(centerDelaySamples * 65536.0)).S(32.W)
  private val depthQ16       = BigInt(Math.round(depthSamples * 65536.0)).S(32.W)

  private val coef070 = FixedPointQ31.doubleToQ31BigInt(0.70).S(32.W)
  private val coef030 = FixedPointQ31.doubleToQ31BigInt(0.30).S(32.W)

  private val mixQ31         = FixedPointQ31.doubleToQ31BigInt(mix).S(32.W)
  private val oneMinusMixQ31 = FixedPointQ31.doubleToQ31BigInt(1.0 - mix).S(32.W)

  val writePtrReg  = RegInit(0.U(delayBufAddrW.W))
  val lfoPhaseReg  = RegInit(0.U(24.W))
  val prevWetReg   = RegInit(0.S(32.W))
  val outSampleReg = RegInit(0.S(32.W))
  val outValidReg  = RegInit(false.B)

  // Pipeline registers
  val pipe1 = RegInit(false.B)
  val pipe2 = RegInit(false.B)
  val pipe3 = RegInit(false.B)

  val samplePipe0 = RegInit(0.S(32.W))
  val samplePipe1 = RegInit(0.S(32.W))
  val samplePipe2 = RegInit(0.S(32.W))

  val lfoFracPipe    = RegInit(0.S(32.W))
  val nextIdxReg     = RegInit(0.U(delayBufAddrW.W))
  val delayFracPipe  = RegInit(0.S(32.W))
  val s1Reg          = RegInit(0.S(32.W))

  // LFO address computation
  val lfoIdx     = lfoPhaseReg(23, 15)
  val lfoNextIdx = (lfoIdx +& 1.U)(8, 0)
  val lfoFrac    = Cat(0.U(1.W), lfoPhaseReg(14, 0), 0.U(16.W)).asSInt

  sineRom.io.addrA := lfoIdx
  sineRom.io.addrB := lfoNextIdx

  // Stage 0: Sample Input & RAM Write
  ram.io.weA   := io.sampleValid
  ram.io.addrA := writePtrReg
  ram.io.dinA  := io.sampleIn

  // Default RAM read address
  val ramReadAddr = WireDefault(0.U(delayBufAddrW.W))
  ram.io.addrB := ramReadAddr

  when(io.sampleValid) {
    samplePipe0  := io.sampleIn
    lfoFracPipe  := lfoFrac
    writePtrReg  := (writePtrReg + 1.U)(delayBufAddrW - 1, 0)
    pipe1        := true.B
  }.otherwise {
    pipe1        := false.B
  }

  // Stage 1: Read Sine ROM & compute delay read pointer
  val lfoY0    = sineRom.io.dataA
  val lfoY1    = sineRom.io.dataB
  val lfoDelta = FixedPointQ31.subQ31(lfoY1, lfoY0)
  val lfoVal   = FixedPointQ31.addQ31(lfoY0, FixedPointQ31.multQ31(lfoDelta, lfoFracPipe))

  val modDelayQ16     = FixedPointQ31.multQ31(depthQ16, lfoVal)
  val delaySamplesQ16 = FixedPointQ31.addQ31(centerDelayQ16, modDelayQ16)

  val curWritePtrQ16 = Cat(writePtrReg, 0.U(16.W)).asSInt
  val readPtrQ16     = FixedPointQ31.subQ31(curWritePtrQ16, delaySamplesQ16)

  val floorIdx = readPtrQ16(delayBufAddrW + 15, 16)
  val nextIdx  = (floorIdx +& 1.U)(delayBufAddrW - 1, 0)
  val fracQ31  = Cat(0.U(1.W), readPtrQ16(15, 1)).asSInt

  when(pipe1) {
    ramReadAddr   := floorIdx
    nextIdxReg    := nextIdx
    delayFracPipe := fracQ31
    samplePipe1   := samplePipe0
    pipe2         := true.B
  }.otherwise {
    pipe2         := false.B
  }

  // Stage 2: Capture s1 from RAM & request s2
  when(pipe2) {
    s1Reg       := ram.io.doutB
    ramReadAddr := nextIdxReg
    samplePipe2 := samplePipe1
    pipe3       := true.B
  }.otherwise {
    pipe3       := false.B
  }

  // Stage 3: Capture s2, interpolate & compute final chorus output
  val s2 = ram.io.doutB
  val deltaS = FixedPointQ31.subQ31(s2, s1Reg)
  val rawWet = FixedPointQ31.addQ31(s1Reg, FixedPointQ31.multQ31(deltaS, delayFracPipe))

  val term070 = FixedPointQ31.multQ31(coef070, rawWet)
  val term030 = FixedPointQ31.multQ31(coef030, prevWetReg)
  val warmWet = FixedPointQ31.addQ31(term070, term030)

  val dryTerm  = FixedPointQ31.multQ31(oneMinusMixQ31, samplePipe2)
  val wetTerm  = FixedPointQ31.multQ31(mixQ31, warmWet)
  val finalOut = FixedPointQ31.addQ31(dryTerm, wetTerm)

  when(pipe3) {
    prevWetReg   := warmWet
    lfoPhaseReg  := lfoPhaseReg + phaseStep
    outSampleReg := finalOut
    outValidReg  := true.B
  }.otherwise {
    outValidReg  := false.B
  }

  io.sampleOut := outSampleReg
  io.outValid  := outValidReg
}
