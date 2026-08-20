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

  val fuzz = Module(new FuzzChisel)
  val chorus = Module(new ChorusChiselRedesign)

  fuzz.io.sampleIn := io.sampleIn
  fuzz.io.sampleValid := io.sampleValid
  val stage1Sample = Mux(enableFuzz, fuzz.io.sampleOut, io.sampleIn)
  val stage1Valid = Mux(enableFuzz, fuzz.io.outValid, io.sampleValid)

  chorus.io.sampleIn := stage1Sample
  chorus.io.sampleValid := stage1Valid
  val stage2Sample = Mux(enableChorus, chorus.io.sampleOut, stage1Sample)
  val stage2Valid = Mux(enableChorus, chorus.io.outValid, stage1Valid)

  io.sampleOut := stage2Sample
  io.outValid := stage2Valid

  io.ledFxMaster := fxMasterEnable
  io.ledOverdrive := enableOverdrive
  io.ledFuzz := enableFuzz
  io.ledChorus := enableChorus
  io.ledPhaser := enablePhaser
}

