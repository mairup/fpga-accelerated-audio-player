package dsp.visualizer

import chisel3._
import chisel3.util.HasBlackBoxResource

class FftCore(val n: Int = 1024, val width: Int = 12) extends BlackBox with HasBlackBoxResource {
  override val desiredName = s"R22SdfFFT${n}"

  val io = IO(new Bundle {
    val clock = Input(Clock())
    val reset = Input(Reset())
    val di_en = Input(Bool())
    val di_re = Input(UInt(width.W))
    val di_im = Input(UInt(width.W))
    val do_en = Output(Bool())
    val do_re = Output(UInt(width.W))
    val do_im = Output(UInt(width.W))
  })

  addResource("/vsrc/r22sdf/R22SdfFFT1024.v")
}
