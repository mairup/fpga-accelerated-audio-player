package fpga

import chisel3._
import chisel3.util._

class SigmaDeltaDAC extends Module {
  val io = IO(new Bundle {
    val sampleIn = Input(SInt(32.W))
    val sampleValid = Input(Bool())
    val pwmOut = Output(Bool())
  })

  val activeSample = RegInit(0.S(48.W))
  val accumulator  = RegInit(0.S(48.W))

  val FULL_SCALE = (1L << 31).S(48.W)

  when(io.sampleValid) {
    activeSample := io.sampleIn.pad(48)
  }

  val nextAcc = Mux(accumulator >= 0.S,
    accumulator + activeSample - FULL_SCALE,
    accumulator + activeSample + FULL_SCALE
  )

  accumulator := nextAcc
  io.pwmOut := accumulator >= 0.S
}
