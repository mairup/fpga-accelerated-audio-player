package fpga

import chisel3._
import chisel3.util._

class JaDriveTop extends Module {
  val io = IO(new Bundle {
    val jaPins = Output(Vec(8, Bool()))
    val txSerialPin = Output(Bool())
  })

  withReset(false.B.asAsyncReset) {
    val uart = Module(new UartTransmitter(100_000_000, 115200))
    io.txSerialPin := uart.io.serialTxPin

    val halfPeriodsMs = Seq(20, 30, 50, 70, 110, 150, 210, 270)

    for (k <- 0 until 8) {
      val halfCycles = halfPeriodsMs(k) * 100_000
      val cnt = RegInit(0.U(26.W))
      val outReg = RegInit(false.B)
      cnt := cnt + 1.U
      when(cnt === (halfCycles - 1).U) {
        cnt := 0.U
        outReg := !outReg
      }
      io.jaPins(k) := outReg
    }

    val windowTimer = RegInit(0.U(27.W))
    val windowClear = WireDefault(false.B)
    windowTimer := windowTimer + 1.U
    when(windowTimer === (100_000_000 - 1).U) {
      windowTimer := 0.U
      windowClear := true.B
    }

    val msgBuf = VecInit("ALIVE\r\n".map(_.toInt.U(8.W)))
    val msgLen = msgBuf.length

    val msgIndex = RegInit(0.U(4.W))
    val msgTransmitting = RegInit(false.B)

    when(windowClear && !msgTransmitting && uart.io.transmitterReady) {
      msgTransmitting := true.B
      msgIndex := 0.U
    }

    when(msgTransmitting) {
      when(uart.io.transmitterReady) {
        when(msgIndex === (msgLen - 1).U) {
          msgTransmitting := false.B
        }.otherwise {
          msgIndex := msgIndex + 1.U
        }
      }
    }

    uart.io.inputDataByte := msgBuf(msgIndex)
    uart.io.transmitValid := msgTransmitting
  }
}

object JaDriveTopApp extends App {
  (new chisel3.stage.ChiselStage).emitVerilog(
    new JaDriveTop,
    Array("--target-dir", ".", "--output-file", "JaDriveTop.v")
  )
  println("Successfully generated Verilog in JaDriveTop.v")
}
