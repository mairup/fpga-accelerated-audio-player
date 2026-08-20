package fpga

import chisel3._
import chisel3.util._

class LedMatrixTestTopIO extends Bundle {
  val cpuResetN = Input(Bool())
  val swPattern = Input(UInt(2.W)) // SW0, SW1
  val swSpeed   = Input(Bool())     // SW2 (fast/slow)

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

    // 4. Drive PMOD JC (Columns / Anodes -> Active HIGH: 1 = ON)
    io.jc1  := colAnodes(0)
    io.jc2  := colAnodes(1)
    io.jc3  := colAnodes(2)
    io.jc4  := colAnodes(3)
    io.jc7  := colAnodes(4)
    io.jc8  := colAnodes(5)
    io.jc9  := colAnodes(6)
    io.jc10 := colAnodes(7)

    // 5. Drive PMOD JD (Rows / Cathodes -> Active LOW: 0 = GROUND / ON, 1 = OFF)
    val rowCathodes = Wire(Vec(8, Bool()))
    for (r <- 0 until 8) {
      rowCathodes(r) := !(activeRow === r.U)
    }
    io.jd1  := rowCathodes(0)
    io.jd2  := rowCathodes(1)
    io.jd3  := rowCathodes(2)
    io.jd4  := rowCathodes(3)
    io.jd7  := rowCathodes(4)
    io.jd8  := rowCathodes(5)
    io.jd9  := rowCathodes(6)
    io.jd10 := rowCathodes(7)
  }
}

object LedMatrixTestTopApp extends App {
  (new chisel3.stage.ChiselStage).emitVerilog(
    new LedMatrixTestTop,
    Array("--target-dir", ".", "--output-file", "LedMatrixTestTop.v")
  )
  println("Successfully generated Verilog in LedMatrixTestTop.v")
}
