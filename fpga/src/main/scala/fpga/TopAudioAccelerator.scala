package fpga

import chisel3._
import chisel3.util._
import dsp.AudioPipeline

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

  val swOutMaster  = Input(Bool())
  val swFxMaster   = Input(Bool())
  val swOverdrive  = Input(Bool())
  val swChorus     = Input(Bool())
  val swTremolo    = Input(Bool())
  val swTestTone   = Input(Bool())
  val swTestPwm    = Input(Bool())
  val txSerialPin = Output(Bool())

  val ledOutMaster  = Output(Bool())
  val ledFxMaster   = Output(Bool())
  val ledOverdrive  = Output(Bool())
  val ledChorus    = Output(Bool())
  val ledTremolo   = Output(Bool())

  val ledBclkAct = Output(Bool())
  val ledWsAct   = Output(Bool())
  val ledRxValid = Output(Bool())
  val ledVolume  = Output(UInt(5.W))
  val ledTestPwm  = Output(Bool())
  val ledTestTone = Output(Bool())

  // PMOD JC: 8 Pins
  val jc1  = Output(Bool())
  val jc2  = Output(Bool())
  val jc3  = Output(Bool())
  val jc4  = Output(Bool())
  val jc7  = Output(Bool())
  val jc8  = Output(Bool())
  val jc9  = Output(Bool())
  val jc10 = Output(Bool())

  // PMOD JD: 8 Pins
  val jd1  = Output(Bool())
  val jd2  = Output(Bool())
  val jd3  = Output(Bool())
  val jd4  = Output(Bool())
  val jd7  = Output(Bool())
  val jd8  = Output(Bool())
  val jd9  = Output(Bool())
  val jd10 = Output(Bool())
}

class TopAudioAccelerator extends RawModule {
  val clock = IO(Input(Clock()))
  val io = IO(new TopAudioAcceleratorIO)

  def toHexAscii(nibble: UInt): UInt = Mux(nibble < 10.U, nibble + '0'.U(8.W), nibble - 10.U + 'A'.U(8.W))

  withClockAndReset(clock, !io.cpuResetN) {
    val i2sController = Module(new I2sController)
    val audioPipeline = Module(new AudioPipeline)
    val dac = Module(new SigmaDeltaDAC)
    val uartTransmitter = Module(new UartTransmitter(100_000_000, 115200))
    io.txSerialPin := uartTransmitter.io.serialTxPin

    i2sController.io.bclk := io.bclk
    i2sController.io.ws := io.ws
    i2sController.io.sdOut := io.sdOut

    audioPipeline.io.sampleIn := i2sController.io.pcmRx
    audioPipeline.io.sampleValid := i2sController.io.pcmRxValid
    audioPipeline.io.swFxMaster := io.swFxMaster
    audioPipeline.io.swOverdrive := io.swOverdrive
    audioPipeline.io.swChorus := io.swChorus
    audioPipeline.io.swTremolo := io.swTremolo

    val visualizer = Module(new dsp.visualizer.VisualizerTop(1024, 8, 12, 24))
    visualizer.io.sampleIn := i2sController.io.pcmRx
    visualizer.io.sampleValid := i2sController.io.pcmRxValid

    val absSample = Mux(i2sController.io.pcmRx < 0.S, (-i2sController.io.pcmRx).asUInt, i2sController.io.pcmRx.asUInt)

    val peakVol = RegInit(0.U(5.W))
    when(i2sController.io.pcmRxValid) {
      when(absSample(30, 26) > peakVol) {
        peakVol := absSample(30, 26)
      }
    }

    val timer10Hz = RegInit(0.U(24.W))
    val trigger10Hz = WireDefault(false.B)
    val latchedBands = RegInit(VecInit(Seq.fill(8)(0.U(24.W))))
    val latchedVol = RegInit(0.U(5.W))

    when(timer10Hz === 9_999_999.U) {
      timer10Hz := 0.U
      trigger10Hz := true.B
      latchedBands := visualizer.io.catVolume
      latchedVol := peakVol
      peakVol := 0.U
    }.otherwise {
      timer10Hz := timer10Hz + 1.U
    }

    val bandAscii = VecInit((0 until 8).map(i => dsp.visualizer.VisualizerConfig.quantizeToAscii(latchedBands(i), i)))
    val volHexHigh = toHexAscii(Cat(0.U(3.W), latchedVol(4)))
    val volHexLow  = toHexAscii(latchedVol(3, 0))

    val msgBuf = VecInit(
      bandAscii.toSeq ++ Seq(
        ' '.U(8.W),
        'V'.U(8.W),
        ':'.U(8.W),
        volHexHigh,
        volHexLow,
        '\r'.U(8.W),
        '\n'.U(8.W)
      )
    )
    val msgLength = 15
    val msgIndex = RegInit(0.U(5.W))
    val msgTransmitting = RegInit(false.B)

    when(trigger10Hz && !msgTransmitting && uartTransmitter.io.transmitterReady) {
      msgTransmitting := true.B
      msgIndex := 0.U
    }

    when(msgTransmitting) {
      when(uartTransmitter.io.transmitterReady) {
        when(msgIndex === (msgLength - 1).U) {
          msgTransmitting := false.B
        }.otherwise {
          msgIndex := msgIndex + 1.U
        }
      }
    }

    uartTransmitter.io.inputDataByte := msgBuf(msgIndex)
    uartTransmitter.io.transmitValid := msgTransmitting

    val sysClkDiv = RegInit(0.U(12.W))
    val sampleStrobe = WireDefault(false.B)
    when(sysClkDiv === 2083.U) {
      sysClkDiv := 0.U
      sampleStrobe := true.B
    }.otherwise {
      sysClkDiv := sysClkDiv + 1.U
    }

    val tonePhase = RegInit(0.U(32.W))
    when(sampleStrobe) {
      tonePhase := tonePhase + 39371073.U
    }
    val toneSample = Mux(tonePhase(31), (-1073741824).S(32.W), 1073741824.S(32.W))

    val audioToDac = Mux(io.swTestTone || io.swTestPwm, toneSample,
                     Mux(io.swOutMaster, audioPipeline.io.sampleOut, 0.S(32.W)))
    val dacValid   = Mux(io.swTestTone || io.swTestPwm, sampleStrobe, audioPipeline.io.outValid)

    dac.io.sampleIn := audioToDac
    dac.io.sampleValid := dacValid

    // Output is enabled if SW15 (Test Tone), SW14 (Test PWM), or SW0 (Master Out) is ON
    val audioEnabled = io.swTestTone || io.swTestPwm || io.swOutMaster
    val activePwm    = Mux(audioEnabled, dac.io.pwmOut, false.B)

    io.audPwm      := activePwm  // Onboard 3.5mm jack (AUD_PWM / Pin A11)
    io.audPwmLeft  := activePwm  // PMOD JA Pin 1 (C17) -> Left Channel Speaker Output
    io.audPwmRight := activePwm  // PMOD JA Pin 2 (D18) -> Right Channel Speaker Output
    io.audPwmExtra := activePwm  // PMOD JA Pin 3 (E18) -> Extra Output
    io.audSd       := true.B

    io.ledOutMaster := io.swOutMaster
    io.ledFxMaster  := audioPipeline.io.ledFxMaster
    io.ledOverdrive := audioPipeline.io.ledOverdrive
    io.ledChorus    := audioPipeline.io.ledChorus
    io.ledTremolo   := audioPipeline.io.ledTremolo
    io.ledTestPwm   := io.swTestPwm
    io.ledTestTone  := io.swTestTone

    val bclkToggle = RegInit(false.B)
    val bclkSync = RegNext(RegNext(io.bclk))
    val bclkPrev = RegNext(bclkSync)
    when(bclkSync && !bclkPrev) {
      bclkToggle := !bclkToggle
    }
    io.ledBclkAct := bclkToggle

    val wsToggle = RegInit(false.B)
    val wsSync = RegNext(RegNext(io.ws))
    val wsPrev = RegNext(wsSync)
    when(wsSync =/= wsPrev) {
      wsToggle := !wsToggle
    }
    io.ledWsAct := wsToggle

    val validStretch = RegInit(0.U(24.W))
    when(i2sController.io.pcmRxValid) {
      validStretch := 5000000.U
    }.elsewhen(validStretch > 0.U) {
      validStretch := validStretch - 1.U
    }
    io.ledRxValid := validStretch > 0.U

    io.ledVolume := absSample(30, 26)

    // 8x8 LED Matrix Spectrum Visualizer on PMOD JC & JD
    val matrixVisualizer = Module(new dsp.visualizer.LedMatrixVisualizer(100_000_000, 1000, 1))
    matrixVisualizer.io.bandMagnitudes := visualizer.io.catVolume
    io.jc1  := matrixVisualizer.io.jc1
    io.jc2  := matrixVisualizer.io.jc2
    io.jc3  := matrixVisualizer.io.jc3
    io.jc4  := matrixVisualizer.io.jc4
    io.jc7  := matrixVisualizer.io.jc7
    io.jc8  := matrixVisualizer.io.jc8
    io.jc9  := matrixVisualizer.io.jc9
    io.jc10 := matrixVisualizer.io.jc10

    io.jd1  := matrixVisualizer.io.jd1
    io.jd2  := matrixVisualizer.io.jd2
    io.jd3  := matrixVisualizer.io.jd3
    io.jd4  := matrixVisualizer.io.jd4
    io.jd7  := matrixVisualizer.io.jd7
    io.jd8  := matrixVisualizer.io.jd8
    io.jd9  := matrixVisualizer.io.jd9
    io.jd10 := matrixVisualizer.io.jd10
  }
}

object TopAudioAcceleratorApp extends App {
  (new chisel3.stage.ChiselStage).emitVerilog(
    new TopAudioAccelerator,
    Array("--target-dir", ".", "--output-file", "TopAudioAccelerator.v")
  )
  println("Successfully generated Verilog in TopAudioAccelerator.v")
}
