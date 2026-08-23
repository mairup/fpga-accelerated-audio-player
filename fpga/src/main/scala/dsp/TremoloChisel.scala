package dsp

import chisel3._
import chisel3.util._

class TremoloChisel(
    val rateHz: Double = 5.0,
    val depth: Double = 0.9,
    val sampleRate: Double = 48000.0
) extends Module {

  val io = IO(new AudioStreamIO(32))

  private val phaseStepValue = BigInt(Math.round(rateHz * (1L << 24).toDouble / sampleRate))
  private val phaseStep = phaseStepValue.U(24.W)

  // Maximum depth dip in gain units (out of 256). depth=0.5 -> depthMax=128
  private val depthMaxValue = BigInt(Math.round(depth * 256.0))
  private val depthMax = depthMaxValue.U(9.W)

  val lfoPhaseCounter = RegInit(0.U(24.W))

  // Triangle LFO: 0 = full dip (minimum volume), 255 = no dip (full volume)
  val isFallingPhase = lfoPhaseCounter(23)
  val rawPhaseBits = lfoPhaseCounter(22, 15)
  val rawTriangleEnvelope = Mux(isFallingPhase, ~rawPhaseBits, rawPhaseBits)

  // Scale: how much of the depth dip to subtract at this LFO phase.
  // When rawTriangle=255 -> dip=0 (full volume=256), when rawTriangle=0 -> dip=depthMax.
  val scaledDip = (depthMax * (255.U - rawTriangleEnvelope)) >> 8
  // Gain peaks at 256 (100%), dips to 256-depthMax = (1-depth)*256
  val modulationEnvelope = (255.U - scaledDip)(8, 0)

  val multipliedSample = (io.sampleIn * modulationEnvelope.asSInt).asSInt
  val modulatedSample = (multipliedSample >> 8).asSInt
  val saturatedSample = FixedPointQ31.saturateSInt(modulatedSample, 32)

  val outputSampleRegister = RegInit(0.S(32.W))
  val outputValidRegister = RegInit(false.B)

  when(io.sampleValid) {
    lfoPhaseCounter := lfoPhaseCounter + phaseStep
    outputSampleRegister := saturatedSample
    outputValidRegister := true.B
  }.otherwise {
    outputValidRegister := false.B
  }

  io.sampleOut := outputSampleRegister
  io.outValid := outputValidRegister
}
