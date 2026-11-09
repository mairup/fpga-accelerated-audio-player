package fpga

import chisel3._
import chisel3.util._

class UartReceiver(clockFrequencyHertz: Int, baudRateBitsPerSecond: Int) extends Module {
  val io = IO(new Bundle {
    val serialRxPin   = Input(Bool())
    val outputDataByte = Output(UInt(8.W))
    val receiveValid  = Output(Bool())
  })

  val clockCyclesPerBit = clockFrequencyHertz / baudRateBitsPerSecond
  val halfBitCycles     = clockCyclesPerBit / 2

  // Synchronizer to avoid metastability
  val rxSync0 = RegNext(io.serialRxPin, true.B)
  val rxSync1 = RegNext(rxSync0, true.B)

  val sIdle :: sStart :: sData :: sStop :: Nil = Enum(4)
  val state = RegInit(sIdle)

  val cycleCounter    = RegInit(0.U(log2Ceil(clockCyclesPerBit + 1).W))
  val bitIndexCounter = RegInit(0.U(3.W))
  val shiftRegister   = RegInit(0.U(8.W))
  val outByteReg      = RegInit(0.U(8.W))
  val outValidReg     = RegInit(false.B)

  outValidReg := false.B

  switch(state) {
    is(sIdle) {
      // Falling edge indicates start bit
      when(!rxSync1) {
        cycleCounter := 0.U
        state        := sStart
      }
    }

    is(sStart) {
      when(cycleCounter === (halfBitCycles - 1).U) {
        cycleCounter := 0.U
        when(!rxSync1) {
          // Confirmed start bit (still low at mid-bit)
          bitIndexCounter := 0.U
          state           := sData
        }.otherwise {
          // False start glitch, return to idle
          state := sIdle
        }
      }.otherwise {
        cycleCounter := cycleCounter + 1.U
      }
    }

    is(sData) {
      when(cycleCounter === (clockCyclesPerBit - 1).U) {
        cycleCounter  := 0.U
        shiftRegister := Cat(rxSync1, shiftRegister(7, 1))

        when(bitIndexCounter === 7.U) {
          state := sStop
        }.otherwise {
          bitIndexCounter := bitIndexCounter + 1.U
        }
      }.otherwise {
        cycleCounter := cycleCounter + 1.U
      }
    }

    is(sStop) {
      when(cycleCounter === (clockCyclesPerBit - 1).U) {
        cycleCounter := 0.U
        state        := sIdle
        when(rxSync1) {
          // Valid stop bit (high)
          outByteReg  := shiftRegister
          outValidReg := true.B
        }
      }.otherwise {
        cycleCounter := cycleCounter + 1.U
      }
    }
  }

  io.outputDataByte := outByteReg
  io.receiveValid  := outValidReg
}
