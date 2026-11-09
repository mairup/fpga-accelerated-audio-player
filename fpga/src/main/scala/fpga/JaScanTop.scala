package fpga

import chisel3._
import chisel3.util._

class JaScanTop extends Module {
  val io = IO(new Bundle {
    val jaPins = Input(Vec(8, Bool()))
    val txSerialPin = Output(Bool())
  })

  withReset(false.B.asAsyncReset) {
    val uart = Module(new UartTransmitter(100_000_000, 115200))
    io.txSerialPin := uart.io.serialTxPin

    val windowTimer = RegInit(0.U(27.W))
    val windowClear = WireDefault(false.B)
    windowTimer := windowTimer + 1.U
    when(windowTimer === (100_000_000 - 1).U) {
      windowTimer := 0.U
      windowClear := true.B
    }

    val latchedCounts = RegInit(VecInit(Seq.fill(8)(0.U(16.W))))

    for (k <- 0 until 8) {
      val sync0 = RegNext(io.jaPins(k), true.B)
      val sync1 = RegNext(sync0, true.B)
      val edge = sync0 =/= sync1
      val cnt = RegInit(0.U(16.W))
      when(windowClear) {
        cnt := Mux(edge, 1.U, 0.U)
        latchedCounts(k) := cnt
      }.elsewhen(edge && !cnt.andR) {
        cnt := cnt + 1.U
      }
    }

    def toHexChar(nibble: UInt): UInt = Mux(nibble < 10.U, nibble + 48.U, nibble + 55.U)

    def hexDigits(value: UInt): Seq[UInt] =
      (3 to 0 by -1).map(i => toHexChar(value(i * 4 + 3, i * 4)))

    val msgBytes = (0 until 8).flatMap { k =>
      (('0' + k).toLong.U(8.W)) +: ('='.U(8.W)) +: (hexDigits(latchedCounts(k)) :+ '\r'.U(8.W) :+ '\n'.U(8.W))
    }

    val msgBuf = VecInit(msgBytes)
    val msgLen = msgBuf.length

    val msgIndex = RegInit(0.U(7.W))
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

object JaScanTopApp extends App {
  (new chisel3.stage.ChiselStage).emitVerilog(
    new JaScanTop,
    Array("--target-dir", ".", "--output-file", "JaScanTop.v")
  )
  println("Successfully generated Verilog in JaScanTop.v")
}
