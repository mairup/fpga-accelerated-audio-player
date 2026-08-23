package dsp

import chisel3._
import chisel3.util._

class AudioPipelineIO extends Bundle {
  val swFxMaster  = Input(Bool())
  val swOverdrive = Input(Bool())
  val swChorus    = Input(Bool())
  val swTremolo   = Input(Bool())

  val sampleIn    = Input(SInt(32.W))
  val sampleValid = Input(Bool())
  val sampleOut   = Output(SInt(32.W))
  val outValid    = Output(Bool())

  val ledFxMaster  = Output(Bool())
  val ledOverdrive = Output(Bool())
  val ledChorus    = Output(Bool())
  val ledTremolo   = Output(Bool())
}

class AudioPipeline extends Module {
  val io = IO(new AudioPipelineIO)

  val fxMasterEnable  = io.swFxMaster
  val enableOverdrive = fxMasterEnable && io.swOverdrive
  val enableChorus    = fxMasterEnable && io.swChorus
  val enableTremolo   = fxMasterEnable && io.swTremolo

  val overdrive = Module(new Overdrive)
  val chorus    = Module(new Chorus)
  val tremolo   = Module(new Tremolo)

  overdrive.io.sampleIn    := io.sampleIn
  overdrive.io.sampleValid := io.sampleValid
  val stage1Sample = Mux(enableOverdrive, overdrive.io.sampleOut, io.sampleIn)
  val stage1Valid  = Mux(enableOverdrive, overdrive.io.outValid, io.sampleValid)

  chorus.io.sampleIn    := stage1Sample
  chorus.io.sampleValid := stage1Valid
  val stage2Sample = Mux(enableChorus, chorus.io.sampleOut, stage1Sample)
  val stage2Valid  = Mux(enableChorus, chorus.io.outValid, stage1Valid)

  tremolo.io.sampleIn    := stage2Sample
  tremolo.io.sampleValid := stage2Valid
  val stage3Sample = Mux(enableTremolo, tremolo.io.sampleOut, stage2Sample)
  val stage3Valid  = Mux(enableTremolo, tremolo.io.outValid, stage2Valid)

  io.sampleOut := stage3Sample
  io.outValid  := stage3Valid

  io.ledFxMaster  := fxMasterEnable
  io.ledOverdrive := enableOverdrive
  io.ledChorus    := enableChorus
  io.ledTremolo   := enableTremolo
}
