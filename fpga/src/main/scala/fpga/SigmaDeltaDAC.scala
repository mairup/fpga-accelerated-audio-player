package fpga

import chisel3._
import chisel3.util._

class SigmaDeltaDAC extends Module {
  val io = IO(new Bundle {
    val sampleIn    = Input(SInt(32.W))
    val sampleValid = Input(Bool())
    val pwmOut      = Output(Bool())
  })

  // Convert 32-bit signed (-2^31 to 2^31-1) to 32-bit unsigned (0 to 2^32-1)
  // Silence (0.S) maps to 0x80000000.U (50% duty cycle at 50 MHz)
  val sampleUnsigned = (io.sampleIn + (1L << 31).S(33.W)).asUInt(31, 0)

  // Linear Interpolator across the ~2083 clock cycles (100 MHz / 48 kHz)
  val currentSample = RegInit(0x80000000L.U(32.W))
  val targetSample  = RegInit(0x80000000L.U(32.W))
  val stepDelta     = RegInit(0.S(32.W))

  when(io.sampleValid) {
    targetSample  := sampleUnsigned
    // diff >> 11 approximates (target - current) / 2048
    val diff      = sampleUnsigned.asSInt - currentSample.asSInt
    stepDelta     := diff >> 11
  }.otherwise {
    currentSample := (currentSample.asSInt + stepDelta).asUInt
  }

  // 32-bit Phase-Accumulator PDM DAC running at full 100 MHz clock
  val accumulator = RegInit(0.U(33.W))
  val nextAcc     = accumulator(31, 0) +& currentSample

  accumulator := nextAcc
  io.pwmOut   := nextAcc(32) // Carry-out is the 1-bit PDM stream
}

