package dsp.visualizer

import chisel3._
import chisel3.util._

class FFTTemporalTrackerIO(val numBins: Int, val dataWidth: Int = 24) extends Bundle {
  val binMagnitudes = Input(Vec(numBins, UInt(dataWidth.W)))
  val valid         = Input(Bool())

  val catVolume     = Output(Vec(numBins, UInt(dataWidth.W)))
  val newUpdate     = Output(Bool())
}

class FFTTemporalTracker(
  val numBins:   Int = 8,
  val width:     Int = 24,
  val decayMult: Int = VisualizerConfig.DecayMult
) extends Module {
  val io = IO(new FFTTemporalTrackerIO(numBins, width))

  val outputRegs  = RegInit(VecInit(Seq.fill(numBins)(0.U(width.W))))
  val updatePulse = RegInit(false.B)

  io.catVolume := outputRegs
  io.newUpdate := updatePulse

  updatePulse := false.B

  when(io.valid) {
    for (i <- 0 until numBins) {
      // Fine fractional exponential decay: decompose into shift-add terms to avoid clocked DSP48E1
      val decayed = if (decayMult >= 256) {
        outputRegs(i)
      } else if (decayMult <= 0) {
        0.U(width.W)
      } else {
        val terms = (0 until 8).filter(b => ((decayMult >> b) & 1) == 1).map(b => outputRegs(i) >> (8 - b).U)
        if (terms.isEmpty) 0.U(width.W)
        else terms.reduce(_ +& _)(width - 1, 0)
      }
      // Fast attack: jump to new peak immediately
      outputRegs(i) := Mux(io.binMagnitudes(i) > decayed, io.binMagnitudes(i), decayed)
    }
    updatePulse := true.B
  }
}
