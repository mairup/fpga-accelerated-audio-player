package fpga

import chisel3._
import chisel3.util._

class StatusLeds extends Module {
  val io = IO(new Bundle {
    val bclk = Input(Bool())
    val ws = Input(Bool())
    val pcmRxValid = Input(Bool())
    val ledBclkAct = Output(Bool())
    val ledWsAct = Output(Bool())
    val ledRxValid = Output(Bool())
  })

  val bclkSync = RegNext(RegNext(io.bclk))
  val bclkPrev = RegNext(bclkSync)
  val bclkToggle = RegInit(false.B)
  when(bclkSync && !bclkPrev) {
    bclkToggle := !bclkToggle
  }
  io.ledBclkAct := bclkToggle

  val wsSync = RegNext(RegNext(io.ws))
  val wsPrev = RegNext(wsSync)
  val wsToggle = RegInit(false.B)
  when(wsSync =/= wsPrev) {
    wsToggle := !wsToggle
  }
  io.ledWsAct := wsToggle

  val validStretch = RegInit(0.U(24.W))
  when(io.pcmRxValid) {
    validStretch := 5000000.U
  }.elsewhen(validStretch > 0.U) {
    validStretch := validStretch - 1.U
  }
  io.ledRxValid := validStretch > 0.U
}
