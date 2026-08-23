package dsp.visualizer

import chisel3._
import chisel3.util._

class FFTMagnitudeBinnerIO(val numBins: Int, val dataWidth: Int = 12, val outWidth: Int = 24) extends Bundle {
  val re        = Input(SInt(dataWidth.W))
  val im        = Input(SInt(dataWidth.W))
  val valid     = Input(Bool())
  val frameDone = Input(Bool())

  val binMagnitudes = Output(Vec(numBins, UInt(outWidth.W)))
  val binValid      = Output(Bool())
}

class FFTMagnitudeBinner(
  val fftSize:     Int = 1024,
  val numBins:     Int = 8,
  val dataWidth:   Int = 12,
  val outWidth:    Int = 24,
  val bitReversed: Boolean = true
) extends Module {
  val io = IO(new FFTMagnitudeBinnerIO(numBins, dataWidth, outWidth))

  val halfN     = fftSize / 2
  val addrWidth = log2Ceil(fftSize)

  val binAccumulators = RegInit(VecInit(Seq.fill(numBins)(0.U(outWidth.W))))
  val binPeaks        = RegInit(VecInit(Seq.fill(numBins)(0.U(outWidth.W))))
  val binCounter      = RegInit(0.U(addrWidth.W))
  val outputRegs      = RegInit(VecInit(Seq.fill(numBins)(0.U(outWidth.W))))
  val outputValid     = RegInit(false.B)

  val absRe     = Mux(io.re < 0.S, (-io.re).asUInt, io.re.asUInt)
  val absIm     = Mux(io.im < 0.S, (-io.im).asUInt, io.im.asUInt)
  val maxVal    = Mux(absRe > absIm, absRe, absIm)
  val minVal    = Mux(absRe > absIm, absIm, absRe)
  // Alpha Max Plus Beta Min approximation: |Z| ~ max + 3/8*min (max error < 3.96%, no DSP multipliers)
  val magnitude = maxVal +& (minVal >> 2) +& (minVal >> 3)

  val naturalIndex = if (bitReversed) {
    Reverse(binCounter(addrWidth - 1, 0))
  } else {
    binCounter
  }

  val usefulBin = naturalIndex < halfN.U

  // Frequency band mapping derived from VisualizerConfig.BandCutoffBins
  val cutoffs = VisualizerConfig.BandCutoffBins
  val targetBinRaw = WireDefault(7.U(3.W))
  when(naturalIndex < cutoffs(0).U)      { targetBinRaw := 0.U }
  .elsewhen(naturalIndex < cutoffs(1).U) { targetBinRaw := 1.U }
  .elsewhen(naturalIndex < cutoffs(2).U) { targetBinRaw := 2.U }
  .elsewhen(naturalIndex < cutoffs(3).U) { targetBinRaw := 3.U }
  .elsewhen(naturalIndex < cutoffs(4).U) { targetBinRaw := 4.U }
  .elsewhen(naturalIndex < cutoffs(5).U) { targetBinRaw := 5.U }
  .elsewhen(naturalIndex < cutoffs(6).U) { targetBinRaw := 6.U }
  // Remaining naturalIndex bins (cutoffs(6) until halfN) map to band 7 (Air)

  val targetBin = if (numBins == 8) targetBinRaw else Mux(targetBinRaw >= numBins.U, (numBins - 1).U, targetBinRaw)

  io.binMagnitudes := outputRegs
  io.binValid      := outputValid

  outputValid := false.B

  when(io.valid) {
    val nextAcc = Wire(Vec(numBins, UInt(outWidth.W)))
    for (i <- 0 until numBins) {
      nextAcc(i) := binAccumulators(i)
    }
    when(usefulBin) {
      nextAcc(targetBin) := binAccumulators(targetBin) + magnitude
      // Track running peak magnitude across all bins in each band
      when(magnitude > binPeaks(targetBin)) {
        binPeaks(targetBin) := magnitude
      }
    }

    when(io.frameDone) {
      val averaged = Wire(Vec(numBins, UInt(outWidth.W)))
      for (i <- 0 until numBins) {
        val mult = VisualizerConfig.BandDivMultipliers(i).U(17.W)
        averaged(i) := ((nextAcc(i) * mult) >> 16.U)(outWidth - 1, 0)
      }
      val blended = Wire(Vec(numBins, UInt(outWidth.W)))
      for (i <- 0 until numBins) {
        val diff = Mux(binPeaks(i) > averaged(i), binPeaks(i) - averaged(i), 0.U)
        if (VisualizerConfig.PeakBlendMult >= 256) {
          blended(i) := binPeaks(i)
        } else if (VisualizerConfig.PeakBlendMult <= 0) {
          blended(i) := averaged(i)
        } else {
          val contrib = ((diff * VisualizerConfig.PeakBlendMult.U) >> 8.U)(outWidth - 1, 0)
          blended(i) := averaged(i) + contrib
        }
      }
      outputRegs  := blended
      outputValid := true.B
      binAccumulators.foreach(_ := 0.U)
      binPeaks.foreach(_ := 0.U)
      binCounter := 0.U
    }.otherwise {
      binAccumulators := nextAcc
      binCounter := binCounter + 1.U
    }
  }.elsewhen(io.frameDone) {
    val averaged = Wire(Vec(numBins, UInt(outWidth.W)))
    for (i <- 0 until numBins) {
      val mult = VisualizerConfig.BandDivMultipliers(i).U(17.W)
      averaged(i) := ((binAccumulators(i) * mult) >> 16.U)(outWidth - 1, 0)
    }
    val blended = Wire(Vec(numBins, UInt(outWidth.W)))
    for (i <- 0 until numBins) {
      val diff = Mux(binPeaks(i) > averaged(i), binPeaks(i) - averaged(i), 0.U)
      if (VisualizerConfig.PeakBlendMult >= 256) {
        blended(i) := binPeaks(i)
      } else if (VisualizerConfig.PeakBlendMult <= 0) {
        blended(i) := averaged(i)
      } else {
        val contrib = ((diff * VisualizerConfig.PeakBlendMult.U) >> 8.U)(outWidth - 1, 0)
        blended(i) := averaged(i) + contrib
      }
    }
    outputRegs  := blended
    outputValid := true.B
    binAccumulators.foreach(_ := 0.U)
    binPeaks.foreach(_ := 0.U)
    binCounter := 0.U
  }
}
