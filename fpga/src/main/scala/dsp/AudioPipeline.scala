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
  // val fuzz      = Module(new FuzzChisel)
  // val chorus    = Module(new ChorusChisel)
  // val phaser    = Module(new PhaserChisel)

  overdrive.io.sampleIn    := io.sampleIn
  overdrive.io.sampleValid := io.sampleValid
  val stage1Sample = Mux(enableOverdrive, overdrive.io.sampleOut, io.sampleIn)
  val stage1Valid  = Mux(enableOverdrive, overdrive.io.outValid, io.sampleValid)

  // Bypass unused effects to speed up FPGA synthesis & routing
  io.sampleOut := stage1Sample
  io.outValid  := stage1Valid

  io.ledFxMaster  := fxMasterEnable
  io.ledOverdrive := enableOverdrive
  io.ledFuzz      := enableFuzz
  io.ledChorus    := enableChorus
  io.ledPhaser    := enablePhaser
}
