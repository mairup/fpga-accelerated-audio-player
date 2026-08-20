package dsp.visualizer

import chisel3._
import chisel3.util._

class VisualizerTopIO(val numBins: Int) extends Bundle {
  val sampleIn    = Input(SInt(32.W))
  val sampleValid = Input(Bool())
  val catVolume   = Output(Vec(numBins, UInt(32.W)))
  val newUpdate   = Output(Bool())
}

class VisualizerTop(
  val fftSize:         Int = 1024,
  val numBins:         Int = 8,
  val framesPerWindow: Int = 8
) extends Module {
  val io = IO(new VisualizerTopIO(numBins))

  val buffer = Module(new SampleBuffer(fftSize))
  buffer.io.sampleIn    := io.sampleIn
  buffer.io.sampleValid := io.sampleValid

  val fft = Module(new FftCore(fftSize, 32))
  fft.io.clock := clock
  fft.io.reset := reset
  fft.io.di_en := buffer.io.burstValid
  fft.io.di_re := buffer.io.burstOut.asUInt
  fft.io.di_im := 0.U

  val fftOutCount = RegInit(0.U(log2Ceil(fftSize + 1).W))
  val frameDone   = WireDefault(false.B)
  when(fft.io.do_en) {
    fftOutCount := fftOutCount + 1.U
    when(fftOutCount === (fftSize - 1).U) {
      frameDone   := true.B
      fftOutCount := 0.U
    }
  }

  val binner = Module(new FFTMagnitudeBinner(fftSize, numBins))
  binner.io.re        := fft.io.do_re.asSInt
  binner.io.im        := fft.io.do_im.asSInt
  binner.io.valid     := fft.io.do_en
  binner.io.frameDone := frameDone

  val tracker = Module(new FFTTemporalTracker(numBins, framesPerWindow))
  tracker.io.binMagnitudes := binner.io.binMagnitudes
  tracker.io.valid         := binner.io.binValid

  io.catVolume := tracker.io.catVolume
  io.newUpdate := tracker.io.newUpdate
}
