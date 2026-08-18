package fpga

import chisel3._

class JaFreqDriver(val clockHz: Int = 100_000_000) extends Module {
  val io = IO(new Bundle {
    val cpuResetN = Input(Bool())

    val ja1  = Output(Bool())
    val ja2  = Output(Bool())
    val ja3  = Output(Bool())
    val ja4  = Output(Bool())
    val ja7  = Output(Bool())
    val ja8  = Output(Bool())
    val ja9  = Output(Bool())
    val ja10 = Output(Bool())
  })

  withReset(!io.cpuResetN) {
    def squareWave(hz: Int): Bool = {
      val half    = clockHz / (2 * hz)
      val counter = RegInit(0.U(27.W))
      val phase   = RegInit(false.B)
      counter := counter + 1.U
      when(counter === (half - 1).U) {
        counter := 0.U
        phase   := !phase
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
}

object JaFreqDriverApp extends App {
  (new chisel3.stage.ChiselStage).emitVerilog(
    new JaFreqDriver(),
    Array("--target-dir", ".", "--output-file", "JaFreqDriver.v")
  )
}
