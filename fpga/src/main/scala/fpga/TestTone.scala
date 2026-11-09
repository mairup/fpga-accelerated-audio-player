package fpga

import chisel3._
import chisel3.util._

class TestTone extends Module {
  val io = IO(new Bundle {
    val enable = Input(Bool())
    val sample = Output(SInt(32.W))
    val strobe = Output(Bool())
  })

  val CLK_48K_DIV = 2083
  val FREQ_440_PHASE_INC = 39371073

  val sysClkDiv = RegInit(0.U(12.W))
  val sampleStrobe = WireDefault(false.B)

  when(sysClkDiv === (CLK_48K_DIV - 1).U) {
    sysClkDiv := 0.U
    sampleStrobe := true.B
  }.otherwise {
    sysClkDiv := sysClkDiv + 1.U
  }

  val tonePhase = RegInit(0.U(32.W))
  when(sampleStrobe) {
    tonePhase := tonePhase + FREQ_440_PHASE_INC.U
  }

  io.sample := Mux(tonePhase(31), (-1073741824).S(32.W), 1073741824.S(32.W))
  io.strobe := sampleStrobe && io.enable
}
