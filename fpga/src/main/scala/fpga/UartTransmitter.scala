package fpga

import chisel3._
import chisel3.util._

class UartTransmitter(clockFrequencyHertz: Int, baudRateBitsPerSecond: Int) extends Module {
  val io = IO(new Bundle {
    val inputDataByte = Input(UInt(8.W))
    val transmitValid = Input(Bool())
    val transmitterReady = Output(Bool())
    val serialTxPin = Output(Bool())
  })

  val clockCyclesPerBit = clockFrequencyHertz / baudRateBitsPerSecond
  val cycleCounter = RegInit(0.U(log2Ceil(clockCyclesPerBit).W))
  val bitIndexCounter = RegInit(0.U(4.W))

  val shiftRegister = RegInit(1.U(10.W))
  val isTransmittingState = RegInit(false.B)

  io.transmitterReady := !isTransmittingState
  io.serialTxPin := shiftRegister(0)

  when(isTransmittingState) {
    when(cycleCounter === (clockCyclesPerBit - 1).U) {
      cycleCounter := 0.U
      shiftRegister := Cat(1.U(1.W), shiftRegister(9, 1))

      when(bitIndexCounter === 9.U) {
        isTransmittingState := false.B
        bitIndexCounter := 0.U
      }.otherwise {
        bitIndexCounter := bitIndexCounter + 1.U
      }
    }.otherwise {
      cycleCounter := cycleCounter + 1.U
    }
  }.otherwise {
    when(io.transmitValid) {
      shiftRegister := Cat(1.U(1.W), io.inputDataByte, 0.U(1.W))
      isTransmittingState := true.B
      cycleCounter := 0.U
      bitIndexCounter := 0.U
    }
  }
}
