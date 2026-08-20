package dsp.visualizer

import chisel3._
import chisel3.util._

class FFTMagnitudeBinnerIO(val numBins: Int) extends Bundle {
  val re        = Input(SInt(32.W))
  val im        = Input(SInt(32.W))
  val valid     = Input(Bool())
  val frameDone = Input(Bool())

  val binMagnitudes = Output(Vec(numBins, UInt(32.W)))
  val binValid      = Output(Bool())
}

class FFTMagnitudeBinner(
  val fftSize:     Int = 1024,
  val numBins:     Int = 8,
  val bitReversed: Boolean = true
) extends Module {
  val io = IO(new FFTMagnitudeBinnerIO(numBins))

  val halfN     = fftSize / 2
  val addrWidth = log2Ceil(fftSize)

  val binAccumulators = RegInit(VecInit(Seq.fill(numBins)(0.U(32.W))))
  val binCounter      = RegInit(0.U(addrWidth.W))
  val outputRegs      = RegInit(VecInit(Seq.fill(numBins)(0.U(32.W))))
  val outputValid     = RegInit(false.B)

  val absRe     = Mux(io.re < 0.S, (-io.re).asUInt, io.re.asUInt)
  val absIm     = Mux(io.im < 0.S, (-io.im).asUInt, io.im.asUInt)
  val magnitude = absRe +& absIm

  val naturalIndex = if (bitReversed) {
    Reverse(binCounter(addrWidth - 1, 0))
  } else {
    binCounter
  }

  val usefulBin = naturalIndex < halfN.U
  val targetBin = (naturalIndex * numBins.U) / halfN.U

  io.binMagnitudes := outputRegs
  io.binValid      := outputValid

  outputValid := false.B

  when(io.frameDone) {
    outputRegs  := binAccumulators
    outputValid := true.B
    binAccumulators.foreach(_ := 0.U)
    binCounter := 0.U
  }.elsewhen(io.valid) {
    when(usefulBin) {
      binAccumulators(targetBin) := binAccumulators(targetBin) + magnitude
    }
    binCounter := binCounter + 1.U
  }
}
