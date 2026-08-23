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
  val numBins: Int = 8,
  val width:   Int = 24
) extends Module {
  val io = IO(new FFTTemporalTrackerIO(numBins, width))

  val outputRegs  = RegInit(VecInit(Seq.fill(numBins)(0.U(width.W))))
  val updatePulse = RegInit(false.B)

  io.catVolume := outputRegs
  io.newUpdate := updatePulse

  updatePulse := false.B

  when(io.valid) {
    for (i <- 0 until numBins) {
      // Smooth exponential decay: decay by  each frame
      val decayed = outputRegs(i) - (outputRegs(i) >> 1)
      // Fast attack: jump to new peak immediately
      outputRegs(i) := Mux(io.binMagnitudes(i) > decayed, io.binMagnitudes(i), decayed)
    }
    updatePulse := true.B
  }
}
