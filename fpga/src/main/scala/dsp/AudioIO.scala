package dsp

import chisel3._

class AudioStreamIO(val dataWidth: Int = 32) extends Bundle {
  val sampleIn    = Input(SInt(dataWidth.W))
  val sampleValid = Input(Bool())
  val sampleOut   = Output(SInt(dataWidth.W))
  val outValid    = Output(Bool())
}
