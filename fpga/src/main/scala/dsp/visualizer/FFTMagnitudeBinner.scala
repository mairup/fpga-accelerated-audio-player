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

  // Logarithmic (octave-spaced) frequency bands for 48kHz audio (46.875 Hz/bin)
  val targetBinRaw = WireDefault(7.U(3.W))
  when(naturalIndex < 3.U)        { targetBinRaw := 0.U } // ~0 - 140 Hz (Sub-bass)
  .elsewhen(naturalIndex < 6.U)   { targetBinRaw := 1.U } // ~140 - 280 Hz (Bass)
  .elsewhen(naturalIndex < 12.U)  { targetBinRaw := 2.U } // ~280 - 560 Hz (Low-mid)
  .elsewhen(naturalIndex < 24.U)  { targetBinRaw := 3.U } // ~560 - 1125 Hz (Mid)
  .elsewhen(naturalIndex < 48.U)  { targetBinRaw := 4.U } // ~1.1 - 2.25 kHz (Upper-mid)
  .elsewhen(naturalIndex < 96.U)  { targetBinRaw := 5.U } // ~2.25 - 4.5 kHz (Presence)
  .elsewhen(naturalIndex < 192.U) { targetBinRaw := 6.U } // ~4.5 - 9 kHz (Brilliance)
  // Else indices 192..511 map to 7.U (~9 - 24 kHz Air)

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
    }

    when(io.frameDone) {
      outputRegs  := nextAcc
      outputValid := true.B
      binAccumulators.foreach(_ := 0.U)
      binCounter := 0.U
    }.otherwise {
      binAccumulators := nextAcc
      binCounter := binCounter + 1.U
    }
  }.elsewhen(io.frameDone) {
    outputRegs  := binAccumulators
    outputValid := true.B
    binAccumulators.foreach(_ := 0.U)
    binCounter := 0.U
  }
}
