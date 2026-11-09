package fpga

import chisel3._
import chisel3.util._

class ConfigRegisters extends Module {
  val io = IO(new Bundle {
    val uartRx = Input(Bool())
    val regVolume = Output(UInt(16.W))
  })

  val HEADER_BYTE = 0xAA.U(8.W)
  val REG_ID_VOLUME = 0x01.U(8.W)

  val uart = Module(new UartReceiver(100_000_000, 115200))
  uart.io.serialRxPin := io.uartRx

  val sHeader :: sCount :: sRegId :: sValHi :: sValLo :: Nil = Enum(5)
  val state = RegInit(sHeader)
  val regCount = RegInit(0.U(8.W))
  val curRegId = RegInit(0.U(8.W))
  val valHi = RegInit(0.U(8.W))
  val regVolume = RegInit(0x7FFF.U(16.W))

  io.regVolume := regVolume

  val rxData = uart.io.outputDataByte
  val rxValid = uart.io.receiveValid

  when(rxValid) {
    switch(state) {
      is(sHeader) {
        when(rxData === HEADER_BYTE) {
          state := sCount
        }
      }
      is(sCount) {
        regCount := rxData
        when(rxData === 0.U) {
          state := sHeader
        }.otherwise {
          state := sRegId
        }
      }
      is(sRegId) {
        curRegId := rxData
        state := sValHi
      }
      is(sValHi) {
        valHi := rxData
        state := sValLo
      }
      is(sValLo) {
        when(curRegId === REG_ID_VOLUME) {
          regVolume := Cat(valHi, rxData)
        }
        when(regCount === 1.U) {
          state := sHeader
        }.otherwise {
          regCount := regCount - 1.U
          state := sRegId
        }
      }
    }
  }
}
