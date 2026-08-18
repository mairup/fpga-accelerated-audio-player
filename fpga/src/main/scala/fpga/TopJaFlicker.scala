package fpga

import chisel3._

class TopJaFlickerIO extends Bundle {
  val ja1  = Output(Bool())
  val ja2  = Output(Bool())
  val ja3  = Output(Bool())
  val ja4  = Output(Bool())
  val ja7  = Output(Bool())
  val ja8  = Output(Bool())
  val ja9  = Output(Bool())
  val ja10 = Output(Bool())
}

class TopJaFlicker extends Module {
  val io = IO(new TopJaFlickerIO)

  val clockHz = 100_000_000

  def squareWave(hz: Int): Bool = {
    val halfPeriod = clockHz / (2 * hz)
    val counter = RegInit(0.U(26.W))
    val phase = RegInit(false.B)
    counter := counter + 1.U
    when(counter === (halfPeriod - 1).U) {
      counter := 0.U
      phase := !phase
    }
    phase
  }

  io.ja1  := squareWave(1)
  io.ja2  := squareWave(2)
  io.ja3  := squareWave(4)
  io.ja4  := squareWave(8)
  io.ja7  := squareWave(16)
  io.ja8  := squareWave(32)
  io.ja9  := squareWave(64)
  io.ja10 := squareWave(128)
}

object TopJaFlickerApp extends App {
  (new chisel3.stage.ChiselStage).emitVerilog(
    new TopJaFlicker,
    Array("--target-dir", ".", "--output-file", "TopJaFlicker.v")
  )
  println("Successfully generated Verilog in TopJaFlicker.v")
}
