package dsp

import chisel3._
import chisel3.util._

class Chorus(
    val rateHz: Double = 0.25,
    val depthMs: Double = 10.0,
    val centerDelayMs: Double = 50.0,
    val alpha: Double = 0.5,
    val beta: Double = 0.5,
    val sampleRate: Double = 48000.0
) extends Module {

  val io = IO(new AudioStreamIO(32))

  private val delayBufferSize = 4096
  private val delayBufferAddressWidth = log2Ceil(delayBufferSize)

  val delayBufferRam = Module(new DualPortBramRam(delayBufferSize, 32))
  delayBufferRam.io.clock := clock

  private val sineTableEntries = 512
  private val sineTableValues: Seq[BigInt] = (0 until sineTableEntries).map { index =>
    val radians = 2.0 * Math.PI * index.toDouble / sineTableEntries.toDouble
    FixedPointQ31.doubleToQ31BigInt(Math.sin(radians))
  }

  val sineTableRom = Module(new DualPortBramRom(sineTableEntries, 32, sineTableValues))
  sineTableRom.io.clock := clock

  private val phaseStepValue = BigInt(Math.round(rateHz * (1L << 24).toDouble / sampleRate))
  private val phaseStep = phaseStepValue.U(24.W)

  private val centerDelaySamples = Math.round(centerDelayMs * (sampleRate / 1000.0)).toInt
  private val depthSamples = Math.round(depthMs * (sampleRate / 1000.0)).toInt

  private val coef085 = FixedPointQ31.fromDouble(0.25)
  private val coef015 = FixedPointQ31.fromDouble(0.75)

  private val alphaQ31 = FixedPointQ31.fromDouble(alpha)
  private val betaQ31 = FixedPointQ31.fromDouble(beta)

  val writePointer = RegInit(0.U(delayBufferAddressWidth.W))
  val lfoPhaseCounter = RegInit(0.U(24.W))

  val stage1Valid = RegInit(false.B)
  val stage2Valid = RegInit(false.B)
  val stage3Valid = RegInit(false.B)

  val samplePipelineStage0 = RegInit(0.S(32.W))
  val samplePipelineStage1 = RegInit(0.S(32.W))
  val samplePipelineStage2 = RegInit(0.S(32.W))

  val writePointerStage0 = RegInit(0.U(delayBufferAddressWidth.W))
  val targetReadAddressReg = RegInit(0.U(delayBufferAddressWidth.W))
  val previousSmoothedWetReg = RegInit(0.S(32.W))

  val outputSampleRegister = RegInit(0.S(32.W))
  val outputValidRegister = RegInit(false.B)

  val lfoTableIndex = lfoPhaseCounter(23, 15)
  sineTableRom.io.addrA := lfoTableIndex
  sineTableRom.io.addrB := 0.U

  delayBufferRam.io.weA := io.sampleValid
  delayBufferRam.io.addrA := writePointer
  delayBufferRam.io.dinA := io.sampleIn

  when(io.sampleValid) {
    samplePipelineStage0 := io.sampleIn
    writePointerStage0 := writePointer
    writePointer := (writePointer + 1.U)(delayBufferAddressWidth - 1, 0)
    lfoPhaseCounter := lfoPhaseCounter + phaseStep
    stage1Valid := true.B
  }.otherwise {
    stage1Valid := false.B
  }

  val sineValue = sineTableRom.io.dataA
  val sinePadded = sineValue.pad(42)
  val scaledSine = (sinePadded << 9).asSInt - (sinePadded << 5).asSInt // exact sineValue * 480
  val modulationOffset = (scaledSine >> 31).asSInt
  val calculatedDelaySamples = (centerDelaySamples.S + modulationOffset).asUInt

  val clampedDelay = Mux(
    calculatedDelaySamples <= 1.U,
    2.U,
    Mux(
      calculatedDelaySamples >= (delayBufferSize - 1).U,
      (delayBufferSize - 1).U,
      calculatedDelaySamples
    )
  )

  val totalSubtrahend = delayBufferSize.U - clampedDelay
  val computedTargetReadAddress = (writePointerStage0 +& totalSubtrahend)(delayBufferAddressWidth - 1, 0)

  delayBufferRam.io.addrB := Mux(stage1Valid, computedTargetReadAddress, targetReadAddressReg)

  when(stage1Valid) {
    targetReadAddressReg := computedTargetReadAddress
    samplePipelineStage1 := samplePipelineStage0
    stage2Valid := true.B
  }.otherwise {
    stage2Valid := false.B
  }

  val rawWetSample = delayBufferRam.io.doutB
  val term085 = FixedPointQ31.multQ31(coef085, rawWetSample)
  val term015 = FixedPointQ31.multQ31(coef015, previousSmoothedWetReg)
  val smoothedWetSample = FixedPointQ31.addQ31(term085, term015)

  when(stage2Valid) {
    previousSmoothedWetReg := smoothedWetSample
    samplePipelineStage2 := samplePipelineStage1
    stage3Valid := true.B
  }.otherwise {
    stage3Valid := false.B
  }

  val drySignalTerm = FixedPointQ31.multQ31(alphaQ31, samplePipelineStage2)
  val wetSignalTerm = FixedPointQ31.multQ31(betaQ31, previousSmoothedWetReg)
  val mixedOutputSample = FixedPointQ31.addQ31(drySignalTerm, wetSignalTerm)

  when(stage3Valid) {
    outputSampleRegister := mixedOutputSample
    outputValidRegister := true.B
  }.otherwise {
    outputValidRegister := false.B
  }

  io.sampleOut := outputSampleRegister
  io.outValid := outputValidRegister
}
