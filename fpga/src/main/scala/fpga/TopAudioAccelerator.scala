package fpga

import chisel3._
import chisel3.util._
import dsp.AudioPipeline

class TopAudioAcceleratorIO extends Bundle {
  val bclk = Input(Bool())
  val ws = Input(Bool())
  val sdOut = Input(Bool())
  val sdIn = Output(Bool())
  val audPwm = Output(Bool())
  val audSd = Output(Bool())
  val audPwmLeft  = Output(Bool())
  val audPwmRight = Output(Bool())
  val audPwmExtra = Output(Bool())

  val cpuResetN = Input(Bool())

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

  def toHexChar(nibble: UInt): UInt = {
    Mux(nibble < 10.U, nibble + 48.U, nibble + 55.U)
  }

  withReset(!io.cpuResetN) {
    val i2sController = Module(new I2sController)
    val audioPipeline = Module(new AudioPipeline)
    val dac = Module(new SigmaDeltaDAC)
    val uartTransmitter = Module(new UartTransmitter(100_000_000, 115200))
    io.txSerialPin := uartTransmitter.io.serialTxPin

    i2sController.io.bclk := io.bclk
    i2sController.io.ws := io.ws
    i2sController.io.sdOut := io.sdOut
    io.sdIn := i2sController.io.sdIn

    i2sController.io.pcmTx := i2sController.io.pcmRx

    audioPipeline.io.sampleIn := i2sController.io.pcmRx
    audioPipeline.io.sampleValid := i2sController.io.pcmRxValid
    audioPipeline.io.swFxMaster := io.swFxMaster
    audioPipeline.io.swOverdrive := io.swOverdrive
    audioPipeline.io.swFuzz := io.swFuzz
    audioPipeline.io.swChorus := io.swChorus
    audioPipeline.io.swPhaser := io.swPhaser

    val absSample = Mux(i2sController.io.pcmRx < 0.S, (-i2sController.io.pcmRx).asUInt, i2sController.io.pcmRx.asUInt)
    val onPeakTracker = RegInit(0.U(32.W))
    val offPeakTracker = RegInit(0.U(32.W))

    when(i2sController.io.pcmRxValid) {
      when(absSample > 1000.U) {
        when(absSample > onPeakTracker) {
          onPeakTracker := absSample
        }
      }.otherwise {
        when(absSample > offPeakTracker) {
          offPeakTracker := absSample
        }
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

    val on7 = toHexChar(latchedOnPeak(31, 28))
    val on6 = toHexChar(latchedOnPeak(27, 24))
    val on5 = toHexChar(latchedOnPeak(23, 20))
    val on4 = toHexChar(latchedOnPeak(19, 16))
    val on3 = toHexChar(latchedOnPeak(15, 12))
    val on2 = toHexChar(latchedOnPeak(11, 8))
    val on1 = toHexChar(latchedOnPeak(7, 4))
    val on0 = toHexChar(latchedOnPeak(3, 0))

    val off7 = toHexChar(latchedOffPeak(31, 28))
    val off6 = toHexChar(latchedOffPeak(27, 24))
    val off5 = toHexChar(latchedOffPeak(23, 20))
    val off4 = toHexChar(latchedOffPeak(19, 16))
    val off3 = toHexChar(latchedOffPeak(15, 12))
    val off2 = toHexChar(latchedOffPeak(11, 8))
    val off1 = toHexChar(latchedOffPeak(7, 4))
    val off0 = toHexChar(latchedOffPeak(3, 0))

    val msgBuf = VecInit(
      'O'.U(8.W), 'N'.U(8.W), ':'.U(8.W), '0'.U(8.W), 'x'.U(8.W),
      on7, on6, on5, on4, on3, on2, on1, on0,
      ' '.U(8.W), '|'.U(8.W), ' '.U(8.W),
      'O'.U(8.W), 'F'.U(8.W), 'F'.U(8.W), ':'.U(8.W), '0'.U(8.W), 'x'.U(8.W),
      off7, off6, off5, off4, off3, off2, off1, off0,
      '\r'.U(8.W), '\n'.U(8.W)
    )

    val msgIndex = RegInit(0.U(5.W))
    val msgTransmitting = RegInit(false.B)

    when(trigger10Hz && !msgTransmitting && uartTransmitter.io.transmitterReady) {
      msgTransmitting := true.B
      msgIndex := 0.U
    }

    when(msgTransmitting) {
      when(uartTransmitter.io.transmitterReady) {
        when(msgIndex === 25.U) {
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
    val toneSample = Mux(tonePhase(31), (-2147483648).S(32.W), 2147483647.S(32.W))

    val pwmDiv = RegInit(0.U(18.W))
    pwmDiv := pwmDiv + 1.U
    val directPwm = pwmDiv < 113636.U

    val audioToDac = Mux(io.swTestTone, toneSample,
                    Mux(io.swOutMaster, audioPipeline.io.sampleOut, 0.S(32.W)))
    val dacValid = Mux(io.swTestTone, sampleStrobe, audioPipeline.io.outValid)

    dac.io.sampleIn := audioToDac
    dac.io.sampleValid := dacValid

    val basePwm = Mux(io.swTestPwm, directPwm, dac.io.pwmOut)

    // SW15 ON -> Test Tone Mode (440 Hz tone)
    // SW15 OFF -> Live PC Audio Stream from ESP32/Wi-Fi
    // SW14 ON -> Direct PWM Mode (Bypass Sigma-Delta)
    // SW0 ON  -> Enable Audio Output (Master On/Off)
    val audioEnabled = Mux(io.swTestTone, true.B, io.swOutMaster)
    val activePwm = Mux(audioEnabled, basePwm, false.B)

    io.audPwm      := activePwm
    io.audPwmRight := activePwm  // JA Pin 2 (D18) -> Tip (Left Speaker)
    io.audPwmLeft  := activePwm  // JA Pin 1 (C17) -> Middle Ring (Right Speaker)
    io.audPwmExtra := activePwm  // JA Pin 3 (E18)
    io.audSd       := true.B

    io.ledOutMaster := io.swOutMaster
    io.ledFxMaster  := audioPipeline.io.ledFxMaster
    io.ledOverdrive := audioPipeline.io.ledOverdrive
    io.ledFuzz      := audioPipeline.io.ledFuzz
    io.ledChorus    := audioPipeline.io.ledChorus
    io.ledPhaser    := audioPipeline.io.ledPhaser
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
  }
}

object TopAudioAcceleratorApp extends App {
  (new chisel3.stage.ChiselStage).emitVerilog(
    new TopAudioAccelerator,
    Array("--target-dir", ".", "--output-file", "TopAudioAccelerator.v")
  )
  println("Successfully generated Verilog in TopAudioAccelerator.v")
}
