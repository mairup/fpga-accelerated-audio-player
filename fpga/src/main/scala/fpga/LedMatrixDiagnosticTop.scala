package fpga

import chisel3._
import chisel3.util._

class LedMatrixDiagnosticTopIO extends Bundle {
  val cpuResetN = Input(Bool())
  
  // All 16 Switches on Nexys A7:
  // SW[7:0]   -> Drives Rows 1..8
  // SW[15:8]  -> Drives Columns 1..8
  val sw = Input(UInt(16.W))

   // Push buttons for polarity/mode overrides:
   // BTNU: Invert Rows polarity
   // BTND: Invert Cols polarity
   // BTNC: Toggle between Direct Static DC Mode (0) and 1 kHz Multiplexing Mode (1)
   val btnU = Input(Bool())
   val btnD = Input(Bool())
   val btnC = Input(Bool())

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
    val invertRows = RegInit(false.B)
    when(btnUSync && !btnUPrev) {
      invertRows := !invertRows
    }

    val btnDSync = RegNext(RegNext(io.btnD))
    val btnDPrev = RegNext(btnDSync)
    val invertCols = RegInit(false.B)
    when(btnDSync && !btnDPrev) {
      invertCols := !invertCols
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

    val logicalRows = Wire(UInt(8.W))
    val logicalCols = Wire(UInt(8.W))

    when(!muxMode) {
      // MODE 0: Direct Static DC Control
      // SW[7:0]  -> Rows 1..8 (cathode active when 0)
      // SW[15:8] -> Cols 1..8 (anode active when 1)
      logicalRows := io.sw(7, 0)
      logicalCols := io.sw(15, 8)
    }.otherwise {
      // MODE 1: Multiplexed Matrix Mode
      // Active scanRow grounded if enabled in SW[7:0]
      // Columns lit according to SW[15:8]
      val rowEnabled = io.sw(7, 0)(scanRow)
      val activeRowMask = Mux(rowEnabled, (1.U(8.W) << scanRow), 0.U(8.W))
      val activeColMask = Mux(rowEnabled, io.sw(15, 8), 0.U(8.W))

      logicalRows := activeRowMask ^ Fill(8, invertRows)
      logicalCols := activeColMask ^ Fill(8, invertCols)
    }

    // Physical Matrix Driver Module (single source of truth for wiring/polarities)
    val driver = Module(new LedMatrixDriver)
    driver.io.rows := logicalRows
    driver.io.cols := logicalCols
    // Display orientation: default 0.U (upright) for 1-to-1 physical diagnostic
    driver.io.orientation := 0.U

    io.jc1  := driver.io.jc1
    io.jc2  := driver.io.jc2
    io.jc3  := driver.io.jc3
    io.jc4  := driver.io.jc4
    io.jc7  := driver.io.jc7
    io.jc8  := driver.io.jc8
    io.jc9  := driver.io.jc9
    io.jc10 := driver.io.jc10

    io.jd1  := driver.io.jd1
    io.jd2  := driver.io.jd2
    io.jd3  := driver.io.jd3
    io.jd4  := driver.io.jd4
    io.jd7  := driver.io.jd7
    io.jd8  := driver.io.jd8
    io.jd9  := driver.io.jd9
    io.jd10 := driver.io.jd10
  }
}

object LedMatrixDiagnosticTopApp extends App {
  (new chisel3.stage.ChiselStage).emitVerilog(
    new LedMatrixDiagnosticTop,
    Array("--target-dir", ".", "--output-file", "LedMatrixDiagnosticTop.v")
  )
  println("Successfully generated Verilog in LedMatrixDiagnosticTop.v")
}
