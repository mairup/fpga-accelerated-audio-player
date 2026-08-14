package dsp

import chisel3._
import chisel3.util._

class AudioPipelineIO extends Bundle {
  val swFxMaster  = Input(Bool())
  val swOverdrive = Input(Bool())
  val swFuzz      = Input(Bool())
  val swChorus    = Input(Bool())
  val swPhaser    = Input(Bool())

  val sampleIn    = Input(SInt(32.W))
  val sampleValid = Input(Bool())
  val sampleOut   = Output(SInt(32.W))
  val outValid    = Output(Bool())

  val ledFxMaster  = Output(Bool())
  val ledOverdrive = Output(Bool())
  val ledFuzz      = Output(Bool())
  val ledChorus    = Output(Bool())
  val ledPhaser    = Output(Bool())
}

class AudioPipeline extends Module {
  val io = IO(new AudioPipelineIO)

  val fxMasterEnable = io.swFxMaster
  val enableOverdrive = fxMasterEnable && io.swOverdrive
  val enableFuzz      = fxMasterEnable && io.swFuzz
  val enableChorus    = fxMasterEnable && io.swChorus
  val enablePhaser    = fxMasterEnable && io.swPhaser

  val overdrive = Module(new OverdriveChisel)
  val fuzz      = Module(new FuzzChisel)
  val chorus    = Module(new ChorusChisel)
  val phaser    = Module(new PhaserChisel)

  overdrive.io.sampleIn    := io.sampleIn
  overdrive.io.sampleValid := io.sampleValid
  val stage1Sample = Mux(enableOverdrive, overdrive.io.sampleOut, io.sampleIn)

  fuzz.io.sampleIn    := stage1Sample
  fuzz.io.sampleValid := io.sampleValid
  val stage2Sample = Mux(enableFuzz, fuzz.io.sampleOut, stage1Sample)

  chorus.io.sampleIn    := stage2Sample
  chorus.io.sampleValid := io.sampleValid
  val stage3Sample = Mux(enableChorus, chorus.io.sampleOut, stage2Sample)

  phaser.io.sampleIn    := stage3Sample
  phaser.io.sampleValid := io.sampleValid
  val stage4Sample = Mux(enablePhaser, phaser.io.sampleOut, stage3Sample)

  io.sampleOut := stage4Sample
  io.outValid  := io.sampleValid

  io.ledFxMaster  := fxMasterEnable
  io.ledOverdrive := enableOverdrive
  io.ledFuzz      := enableFuzz
  io.ledChorus    := enableChorus
  io.ledPhaser    := enablePhaser
}
