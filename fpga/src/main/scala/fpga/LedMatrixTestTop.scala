package fpga

import chisel3._
import chisel3.util._

class LedMatrixTestTopIO extends Bundle {
  val cpuResetN = Input(Bool())
  val swPattern = Input(UInt(2.W)) // SW0, SW1
  val swSpeed   = Input(Bool())     // SW2
  val orientation = Input(UInt(2.W)) // SW3, SW4 (1 = upright, 2 = 90 deg CW, 3 = 180 deg, 4 = 270 deg CW)

  // PMOD JC: 8 Column Anodes (Active HIGH: 1 = ON)
  val jc1  = Output(Bool())
  val jc2  = Output(Bool())
  val jc3  = Output(Bool())
  val jc4  = Output(Bool())
  val jc7  = Output(Bool())
  val jc8  = Output(Bool())
  val jc9  = Output(Bool())
  val jc10 = Output(Bool())

  // PMOD JD: 8 Row Cathodes (Active LOW: 0 = GROUND / ACTIVE)
  val jd1  = Output(Bool())
  val jd2  = Output(Bool())
  val jd3  = Output(Bool())
  val jd4  = Output(Bool())
  val jd7  = Output(Bool())
  val jd8  = Output(Bool())
  val jd9  = Output(Bool())
  val jd10 = Output(Bool())

  // Onboard status LEDs to mirror current row & pattern
  val ledPattern = Output(UInt(2.W))
  val ledActiveRow = Output(UInt(8.W))
}

class LedMatrixTestTop extends RawModule {
  val clock = IO(Input(Clock()))
  val io = IO(new LedMatrixTestTopIO)

  withClockAndReset(clock, !io.cpuResetN) {
    io.ledPattern := io.swPattern

    // 1. Multiplexing Refresh Counter: 100MHz / 12,500 = 8 kHz row tick (1 kHz full frame rate)
    val refreshDiv = RegInit(0.U(14.W))
    val rowStrobe = WireDefault(false.B)
    when(refreshDiv === 12499.U) {
      refreshDiv := 0.U
      rowStrobe := true.B
    }.otherwise {
      refreshDiv := refreshDiv + 1.U
    }

    val activeRow = RegInit(0.U(3.W))
    when(rowStrobe) {
      activeRow := activeRow + 1.U
    }
    io.ledActiveRow := (1.U << activeRow)

    // 2. Animation Step Timer (approx 30 Hz or 10 Hz)
    val animDiv = RegInit(0.U(24.W))
    val animMax = Mux(io.swSpeed, 1_500_000.U, 4_000_000.U)
    val animTick = WireDefault(false.B)
    when(animDiv >= animMax) {
      animDiv := 0.U
      animTick := true.B
    }.otherwise {
      animDiv := animDiv + 1.U
    }

    val animCounter = RegInit(0.U(6.W))
    when(animTick) {
      animCounter := animCounter + 1.U
    }

    // Single walking pixel coordinates
    val walkCol = animCounter(2, 0)
    val walkRow = animCounter(5, 3)

    // Simulated bouncing equalizer levels (8 columns, height 0-7)
    val eqLevels = Wire(Vec(8, UInt(3.W)))
    for (col <- 0 until 8) {
      val offset = (col * 3).U
      val wave = (animCounter + offset)(3, 0)
      // Bounce up to 7 and down
      eqLevels(col) := Mux(wave > 7.U, 15.U - wave, wave)(2, 0)
    }

    // 3. Compute Column Anode values for the currently active row
    val colAnodes = WireDefault(VecInit(Seq.fill(8)(false.B)))
    for (col <- 0 until 8) {
      switch(io.swPattern) {
        is(0.U) {
          // Equalizer bar animation (stacked upward from row 0)
          colAnodes(col) := eqLevels(col) >= activeRow
        }
        is(1.U) {
          // Walking single pixel (Row walkRow, Col walkCol)
          colAnodes(col) := (activeRow === walkRow) && (col.U(3.W) === walkCol)
        }
        is(2.U) {
          // Checkerboard pattern
          colAnodes(col) := (activeRow(0) ^ (col % 2 != 0).B) === animCounter(0)
        }
        is(3.U) {
          // All LEDs ON (safely multiplexed)
          colAnodes(col) := true.B
        }
      }
    }

    // 4. Unified matrix driver for correct PMOD wiring
    val driver = Module(new LedMatrixDriver)
    driver.io.rows := (1.U(8.W) << activeRow)
    driver.io.cols := colAnodes.asUInt
    driver.io.orientation := io.orientation

    // PMOD JC and JD are now driven by the driver
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

object LedMatrixTestTopApp extends App {
  (new chisel3.stage.ChiselStage).emitVerilog(
    new LedMatrixTestTop,
    Array("--target-dir", ".", "--output-file", "LedMatrixTestTop.v")
  )
  println("Successfully generated Verilog in LedMatrixTestTop.v")
}
