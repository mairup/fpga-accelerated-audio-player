package fpga

import chisel3._
import chisel3.util._

class I2sControllerIO extends Bundle {
  val bclk = Input(Bool())
  val ws = Input(Bool())
  val sdOut = Input(Bool())
  val pcmRx = Output(SInt(32.W))
  val pcmRxValid = Output(Bool())
}

class I2sController extends Module {
  val io = IO(new I2sControllerIO)

  val bclkSync = RegNext(RegNext(io.bclk))
  val bclkPrev = RegNext(bclkSync)
  val bclkRising = bclkSync && !bclkPrev

  val wsSync = RegNext(RegNext(io.ws))
  val wsPrev = RegNext(wsSync)
  val wsEdge = wsSync =/= wsPrev

  val rxShiftReg = RegInit(0.U(32.W))
  val rxBitCounter = RegInit(0.U(7.W))
  val rxSampleReg = RegInit(0.S(32.W))
  val rxValidReg = RegInit(false.B)
  val isLeftChannel = RegInit(false.B)

  rxValidReg := false.B

  when(wsEdge) {
    rxBitCounter := 0.U
    isLeftChannel := !wsSync
  }

  when(bclkRising) {
    val nextRxCounter = rxBitCounter + 1.U
    rxBitCounter := nextRxCounter
    when(nextRxCounter >= 2.U && nextRxCounter <= 16.U) {
      val nextRxShift = Cat(rxShiftReg(13, 0), io.sdOut)
      rxShiftReg := nextRxShift
      when(nextRxCounter === 16.U) {
        val alignedSample = Cat(nextRxShift(14, 0), 0.U(1.W))
        rxSampleReg := (alignedSample ## 0.U(16.W)).asSInt
        when(isLeftChannel) {
          rxValidReg := true.B
        }
      }
    }
  }

  io.pcmRx := rxSampleReg
  io.pcmRxValid := rxValidReg
}

