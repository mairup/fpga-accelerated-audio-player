package fpga

import chisel3._
import chisel3.util._
import dsp.AudioPipeline
import dsp.FixedPointQ31

class TopAudioAcceleratorIO extends Bundle {
  val bclk = Input(Bool())
  val ws = Input(Bool())
  val sdOut = Input(Bool())
  val audPwm = Output(Bool())
  val audSd = Output(Bool())
  val audPwmLeft  = Output(Bool())
  val audPwmRight = Output(Bool())
  val audPwmExtra = Output(Bool())

  val cpuResetN = Input(Bool())
  val uartRxPin = Input(Bool())

  val swOutMaster  = Input(Bool())
  val swFxMaster   = Input(Bool())
  val swOverdrive  = Input(Bool())
  val swFuzz       = Input(Bool())
  val swChorus     = Input(Bool())
  val swPhaser     = Input(Bool())
  val swTestTone   = Input(Bool())
  val swTestPwm    = Input(Bool())
  val txSerialPin = Output(Bool())

  val ledOutMaster  = Output(Bool())
  val ledFxMaster   = Output(Bool())
  val ledOverdrive  = Output(Bool())
  val ledFuzz       = Output(Bool())
  val ledChorus    = Output(Bool())
  val ledPhaser    = Output(Bool())

  val ledBclkAct = Output(Bool())
  val ledWsAct   = Output(Bool())
  val ledRxValid = Output(Bool())
  val ledVolume  = Output(UInt(5.W))
  val ledTestPwm  = Output(Bool())
  val ledTestTone = Output(Bool())
}

class TopAudioAccelerator extends Module {
  val io = IO(new TopAudioAcceleratorIO)

  withReset(!io.cpuResetN) {
    val i2s = Module(new I2sController)
    val pipeline = Module(new AudioPipeline)
    val dac = Module(new SigmaDeltaDAC)
    val telemetry = Module(new UartTelemetry(100_000_000, 115200))
    val testTone = Module(new TestTone)
    val statusLeds = Module(new StatusLeds)
    val configRegs = Module(new ConfigRegisters)

    i2s.io.bclk := io.bclk
    i2s.io.ws := io.ws
    i2s.io.sdOut := io.sdOut

    configRegs.io.uartRx := io.uartRxPin
    io.txSerialPin := telemetry.io.txPin

    pipeline.io.sampleIn := i2s.io.pcmRx
    pipeline.io.sampleValid := i2s.io.pcmRxValid
    pipeline.io.swFxMaster := io.swFxMaster
    pipeline.io.swOverdrive := io.swOverdrive
    pipeline.io.swFuzz := io.swFuzz
    pipeline.io.swChorus := io.swChorus
    pipeline.io.swPhaser := io.swPhaser

    val volumeGainQ31 = Cat(configRegs.io.regVolume, 0.U(16.W)).asSInt
    val scaledOutput = FixedPointQ31.multQ31(pipeline.io.sampleOut, volumeGainQ31)

    val absSample = Mux(i2s.io.pcmRx < 0.S, (-i2s.io.pcmRx).asUInt, i2s.io.pcmRx.asUInt)
    val onPeakTracker = RegInit(0.U(32.W))
    val offPeakTracker = RegInit(0.U(32.W))

    when(i2s.io.pcmRxValid) {
      when(absSample > 1000.U) {
        when(absSample > onPeakTracker) { onPeakTracker := absSample }
      }.otherwise {
        when(absSample > offPeakTracker) { offPeakTracker := absSample }
      }
    }

    val timer10Hz = RegInit(0.U(24.W))
    val trigger10Hz = WireDefault(false.B)
    val latchedOnPeak = RegInit(0.U(32.W))
    val latchedOffPeak = RegInit(0.U(32.W))

    when(timer10Hz === 9_999_999.U) {
      timer10Hz := 0.U
      trigger10Hz := true.B
      latchedOnPeak := onPeakTracker
      latchedOffPeak := offPeakTracker
      onPeakTracker := 0.U
      offPeakTracker := 0.U
    }.otherwise {
      timer10Hz := timer10Hz + 1.U
    }

    telemetry.io.trigger := trigger10Hz
    telemetry.io.onPeak := latchedOnPeak
    telemetry.io.offPeak := latchedOffPeak
    telemetry.io.regVolume := configRegs.io.regVolume

    testTone.io.enable := io.swTestTone || io.swTestPwm

    val audioToDac = Mux(io.swTestTone || io.swTestPwm, testTone.io.sample,
                     Mux(io.swOutMaster, scaledOutput, 0.S(32.W)))
    val dacValid   = Mux(io.swTestTone || io.swTestPwm, testTone.io.strobe, pipeline.io.outValid)

    dac.io.sampleIn := audioToDac
    dac.io.sampleValid := dacValid

    val audioEnabled = io.swTestTone || io.swTestPwm || io.swOutMaster
    val activePwm = Mux(audioEnabled, dac.io.pwmOut, false.B)

    io.audPwm      := activePwm
    io.audPwmLeft  := activePwm
    io.audPwmRight := activePwm
    io.audPwmExtra := activePwm
    io.audSd       := true.B

    io.ledOutMaster := io.swOutMaster
    io.ledFxMaster  := pipeline.io.ledFxMaster
    io.ledOverdrive := pipeline.io.ledOverdrive
    io.ledFuzz      := pipeline.io.ledFuzz
    io.ledChorus    := pipeline.io.ledChorus
    io.ledPhaser    := pipeline.io.ledPhaser
    io.ledTestPwm   := io.swTestPwm
    io.ledTestTone  := io.swTestTone

    statusLeds.io.bclk := io.bclk
    statusLeds.io.ws := io.ws
    statusLeds.io.pcmRxValid := i2s.io.pcmRxValid
    io.ledBclkAct := statusLeds.io.ledBclkAct
    io.ledWsAct   := statusLeds.io.ledWsAct
    io.ledRxValid := statusLeds.io.ledRxValid

    io.ledVolume := absSample(30, 26)
  }
}

object TopAudioAcceleratorApp extends App {
  (new chisel3.stage.ChiselStage).emitVerilog(
    new TopAudioAccelerator,
    Array("--target-dir", ".", "--output-file", "TopAudioAccelerator.v")
  )
  println("Successfully generated Verilog in TopAudioAccelerator.v")
}
