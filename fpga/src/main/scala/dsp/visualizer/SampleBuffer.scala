package dsp.visualizer

import chisel3._
import chisel3.util._

class SampleBufferIO(val depth: Int) extends Bundle {
  val sampleIn    = Input(SInt(32.W))
  val sampleValid = Input(Bool())

  val burstOut    = Output(SInt(32.W))
  val burstValid  = Output(Bool())
  val burstDone   = Output(Bool())
}

class SampleBuffer(val depth: Int = 1024) extends Module {
  val io = IO(new SampleBufferIO(depth))

  val addrWidth = log2Ceil(depth)

  val mem = SyncReadMem(depth, SInt(32.W))

  val writePtr   = RegInit(0.U(addrWidth.W))
  val readPtr    = RegInit(0.U(addrWidth.W))
  val readCount  = RegInit(0.U((addrWidth + 1).W))

  val idle :: bursting :: Nil = Enum(2)
  val state = RegInit(idle)

  val bufferFull = writePtr === 0.U && RegNext(writePtr) === (depth - 1).U

  io.burstOut   := mem.read(readPtr)
  io.burstValid := state === bursting && readCount > 0.U
  io.burstDone  := false.B

  switch(state) {
    is(idle) {
      when(io.sampleValid) {
        mem.write(writePtr, io.sampleIn)
        writePtr := writePtr + 1.U
      }

      when(bufferFull) {
        state   := bursting
        readPtr := 0.U
        readCount := 0.U
      }
    }

    is(bursting) {
      readPtr   := readPtr + 1.U
      readCount := readCount + 1.U

      when(readCount === depth.U) {
        state       := idle
        io.burstDone := true.B
      }
    }
  }
}
