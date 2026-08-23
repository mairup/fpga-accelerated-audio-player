package dsp

import chisel3._
import chisel3.util._

class Tremolo(
    val rateHz: Double = 5.0,
    val depth: Double = 0.9,
    val sampleRate: Double = 48000.0
) extends Module {

  val io = IO(new AudioStreamIO(32))

  private val phaseStepValue = BigInt(Math.round(rateHz * (1L << 24).toDouble / sampleRate))
  private val phaseStep = phaseStepValue.U(24.W)

  // Maximum depth dip in gain units (out of 256). depth=0.9 -> depthMax=230
  private val depthMaxValue = BigInt(Math.round(depth * 256.0))
  private val depthMax = depthMaxValue.U(9.W)

  val lfoPhaseCounter = RegInit(0.U(24.W))

  // Triangle LFO: 0 = full dip (minimum volume), 255 = no dip (full volume)
  val isFallingPhase = lfoPhaseCounter(23)
  val rawPhaseBits = lfoPhaseCounter(22, 15)
  val rawTriangleEnvelope = Mux(isFallingPhase, ~rawPhaseBits, rawPhaseBits)

  // Scale: how much of the depth dip to subtract at this LFO phase.
  val scaledDip = (depthMax * (255.U - rawTriangleEnvelope)) >> 8
  // Gain peaks at 256 (100%), dips to 256-depthMax
  val modulationEnvelope = (255.U - scaledDip)(8, 0)

  // Audio sample is 32-bit. Take top 24 bits so the 24x10 multiplier fits in a single DSP48E1 (25x18 max).
  val sampleIn24 = (io.sampleIn >> 8).asSInt
  val multipliedSample = (sampleIn24 * modulationEnvelope.asSInt).asSInt
  val saturatedSample = FixedPointQ31.saturateSInt(multipliedSample, 32)

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
