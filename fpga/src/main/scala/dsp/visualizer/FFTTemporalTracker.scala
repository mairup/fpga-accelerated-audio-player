package dsp.visualizer

import chisel3._
import chisel3.util._

class FFTTemporalTrackerIO(val numBins: Int) extends Bundle {
  val binMagnitudes = Input(Vec(numBins, UInt(32.W)))
  val valid         = Input(Bool())

  val catVolume     = Output(Vec(numBins, UInt(32.W)))
  val newUpdate     = Output(Bool())
}

class FFTTemporalTracker(
  val numBins:         Int = 8,
  val framesPerWindow: Int = 8
) extends Module {
  val io = IO(new FFTTemporalTrackerIO(numBins))

  val frameCounter = RegInit(0.U(log2Ceil(framesPerWindow + 1).W))
  val peakRegs     = RegInit(VecInit(Seq.fill(numBins)(0.U(32.W))))
  val outputRegs   = RegInit(VecInit(Seq.fill(numBins)(0.U(32.W))))
  val updatePulse  = RegInit(false.B)

  io.catVolume := outputRegs
  io.newUpdate := updatePulse

  updatePulse := false.B

  when(io.valid) {
    val updatedPeaks = Wire(Vec(numBins, UInt(32.W)))
    for (i <- 0 until numBins) {
      updatedPeaks(i) := Mux(io.binMagnitudes(i) > peakRegs(i), io.binMagnitudes(i), peakRegs(i))
      peakRegs(i) := updatedPeaks(i)
    }

    frameCounter := frameCounter + 1.U

    when(frameCounter === (framesPerWindow - 1).U) {
      frameCounter := 0.U
      outputRegs   := updatedPeaks
      updatePulse  := true.B
      peakRegs.foreach(_ := 0.U)
    }
  }
}
