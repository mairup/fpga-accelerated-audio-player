package fpga

import chisel3._
import chisel3.util._

class UartTelemetry(clockFrequencyHertz: Int, baudRate: Int) extends Module {
  val io = IO(new Bundle {
    val trigger = Input(Bool())
    val onPeak = Input(UInt(32.W))
    val offPeak = Input(UInt(32.W))
    val regVolume = Input(UInt(16.W))
    val txPin = Output(Bool())
  })

  val uart = Module(new UartTransmitter(clockFrequencyHertz, baudRate))
  io.txPin := uart.io.serialTxPin

  def toHexChar(nibble: UInt): UInt = Mux(nibble < 10.U, nibble + 48.U, nibble + 55.U)

  def hex8(value: UInt, base: Int): Vec[UInt] = VecInit.tabulate(8) { i =>
    toHexChar(value((base + i) * 4 + 3, (base + i) * 4))
  }

  def hex4(value: UInt, base: Int): Vec[UInt] = VecInit.tabulate(4) { i =>
    toHexChar(value((base + i) * 4 + 3, (base + i) * 4))
  }

  val onHex = hex8(io.onPeak, 0)
  val offHex = hex8(io.offPeak, 0)
  val volHex = hex4(io.regVolume, 0)

  val msgBuf = VecInit(
    'V'.U, 'O'.U, 'L'.U, ':'.U, '0'.U, 'x'.U,
    volHex(3), volHex(2), volHex(1), volHex(0),
    ' '.U, '|'.U, ' '.U,
    'O'.U, 'N'.U, ':'.U, '0'.U, 'x'.U,
    onHex(7), onHex(6), onHex(5), onHex(4), onHex(3), onHex(2), onHex(1), onHex(0),
    ' '.U, '|'.U, ' '.U,
    'O'.U, 'F'.U, 'F'.U, ':'.U, '0'.U, 'x'.U,
    offHex(7), offHex(6), offHex(5), offHex(4), offHex(3), offHex(2), offHex(1), offHex(0),
    '\r'.U, '\n'.U
  )

  val msgLen = 45
  val msgIndex = RegInit(0.U(6.W))
  val msgTransmitting = RegInit(false.B)

  when(io.trigger && !msgTransmitting && uart.io.transmitterReady) {
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
