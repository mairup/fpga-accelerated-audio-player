package fpga

import chisel3._
import chisel3.util._

class LedMatrixDiagnosticTopIO extends Bundle {
  val cpuResetN = Input(Bool())
  
  // All 16 Switches on Nexys A7:
  // SW[7:0]   -> Drives PMOD JC (Columns 0..7)
  // SW[15:8]  -> Drives PMOD JD (Rows 0..7)
  val sw = Input(UInt(16.W))

  // Push buttons for polarity/mode overrides:
  // BTNU: Invert JD polarity (active-1 vs active-0)
  // BTND: Invert JC polarity (active-1 vs active-0)
  // BTNC: Toggle between Direct Static DC Mode (0) and 1 kHz Multiplexing Mode (1)
  val btnU = Input(Bool())
  val btnD = Input(Bool())
  val btnC = Input(Bool())

  // PMOD JC: 8 Column Pins
  val jc1  = Output(Bool())
  val jc2  = Output(Bool())
  val jc3  = Output(Bool())
  val jc4  = Output(Bool())
  val jc7  = Output(Bool())
  val jc8  = Output(Bool())
  val jc9  = Output(Bool())
  val jc10 = Output(Bool())

  // PMOD JD: 8 Row Pins
  val jd1  = Output(Bool())
  val jd2  = Output(Bool())
  val jd3  = Output(Bool())
  val jd4  = Output(Bool())
  val jd7  = Output(Bool())
  val jd8  = Output(Bool())
  val jd9  = Output(Bool())
  val jd10 = Output(Bool())

  // 16 Onboard LEDs: mirror switch inputs
  val leds = Output(UInt(16.W))
}

class LedMatrixDiagnosticTop extends RawModule {
  val clock = IO(Input(Clock()))
  val io = IO(new LedMatrixDiagnosticTopIO)

  withClockAndReset(clock, !io.cpuResetN) {
    io.leds := io.sw

    // Debounce/toggle for BTNC (Mode: 0 = Direct Static DC, 1 = Multiplexed)
    val btnCSync = RegNext(RegNext(io.btnC))
    val btnCPrev = RegNext(btnCSync)
    val muxMode  = RegInit(false.B)
    when(btnCSync && !btnCPrev) {
      muxMode := !muxMode
    }

    // Polarity toggles
    val btnUSync = RegNext(RegNext(io.btnU))
    val btnUPrev = RegNext(btnUSync)
    val invertJD = RegInit(false.B)
    when(btnUSync && !btnUPrev) {
      invertJD := !invertJD
    }

    val btnDSync = RegNext(RegNext(io.btnD))
    val btnDPrev = RegNext(btnDSync)
    val invertJC = RegInit(false.B)
    when(btnDSync && !btnDPrev) {
      invertJC := !invertJC
    }

    // Multiplexing counter: 100MHz / 12500 = 8 kHz row tick (1 kHz full frame)
    val refreshDiv = RegInit(0.U(14.W))
    val rowStrobe  = WireDefault(false.B)
    when(refreshDiv === 12499.U) {
      refreshDiv := 0.U
      rowStrobe  := true.B
    }.otherwise {
      refreshDiv := refreshDiv + 1.U
    }

    val scanRow = RegInit(0.U(3.W))
    when(rowStrobe) {
      scanRow := scanRow + 1.U
    }

    val jcOut = Wire(Vec(8, Bool()))
    val jdOut = Wire(Vec(8, Bool()))

    when(!muxMode) {
      // MODE 0: Direct Static DC Control
      // Each switch directly forces high/low on the corresponding PMOD pin
      // SW[7:0]  -> JC[0..7] (Default: 1 = 3.3V, 0 = 0V)
      // SW[15:8] -> JD[0..7] (Default: 1 = 0V / GND, 0 = 3.3V)
      for (i <- 0 until 8) {
        val rawJC = io.sw(i)
        jcOut(i) := Mux(invertJC, !rawJC, rawJC)

        val rawJD = io.sw(i + 8)
        jdOut(i) := Mux(invertJD, rawJD, !rawJD)
      }
    }.otherwise {
      // MODE 1: Multiplexed Matrix Mode
      // Only the active scan row is grounded (0V), others 3.3V
      // Columns lit according to SW[7:0] for any row enabled in SW[15:8]
      val rowEnabled = io.sw(scanRow + 8.U)
      for (c <- 0 until 8) {
        val colActive = rowEnabled && io.sw(c)
        jcOut(c) := Mux(invertJC, !colActive, colActive)
      }

      for (r <- 0 until 8) {
        val rowIsActive = (scanRow === r.U) && io.sw(r + 8)
        jdOut(r) := Mux(invertJD, rowIsActive, !rowIsActive)
      }
    }

    // Drive PMOD JC
    io.jc1  := jcOut(0)
    io.jc2  := jcOut(1)
    io.jc3  := jcOut(2)
    io.jc4  := jcOut(3)
    io.jc7  := jcOut(4)
    io.jc8  := jcOut(5)
    io.jc9  := jcOut(6)
    io.jc10 := jcOut(7)

    // Drive PMOD JD
    io.jd1  := jdOut(0)
    io.jd2  := jdOut(1)
    io.jd3  := jdOut(2)
    io.jd4  := jdOut(3)
    io.jd7  := jdOut(4)
    io.jd8  := jdOut(5)
    io.jd9  := jdOut(6)
    io.jd10 := jdOut(7)
  }
}

object LedMatrixDiagnosticTopApp extends App {
  (new chisel3.stage.ChiselStage).emitVerilog(
    new LedMatrixDiagnosticTop,
    Array("--target-dir", ".", "--output-file", "LedMatrixDiagnosticTop.v")
  )
  println("Successfully generated Verilog in LedMatrixDiagnosticTop.v")
}
