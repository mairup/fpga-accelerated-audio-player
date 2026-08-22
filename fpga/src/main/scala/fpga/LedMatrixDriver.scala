package fpga

import chisel3._
import chisel3.util._

/** Physical 8x8 LED Matrix Driver.
 *
 *  Single source of truth for the physical pin mapping and polarity
 *  between logical (row, col) coordinates and Nexys A7 PMOD JC/JD headers.
 *
 *  Orientation selects the displayed rotation of the 8x8 image (each step 90 degrees clockwise):
 *    - 0 / 1 : upright        (r, c)                 -> (r,            c)
 *    - 2     : 90 degrees CW  (r, c)                 -> (c,            7-r)
 *    - 3     : 180 degrees    (r, c)                 -> (7-r,          7-c)
 *    - 4     : 270 degrees CW (r, c)                 -> (7-c,          r)
 *
 *  Logical coordinates (both active-high):
 *    - rows(i) = 1 -> Row (i+1) is ACTIVE (driven HIGH to +3.3V, Anode)
 *    - cols(i) = 1 -> Column (i+1) is ACTIVE (driven LOW to 0V/Ground, Cathode)
 *
 *  Physical Mapping on Nexys A7:
 *    - Rows (Anodes, Active HIGH):
 *        R1 -> JC4
 *        R2 -> JD8
 *        R3 -> JD10
 *        R4 -> JC9
 *        R5 -> JD1
 *        R6 -> JC8
 *        R7 -> JC2
 *        R8 -> JC1
 *
 *    - Columns (Cathodes, Active LOW):
 *        C1 -> JC10
 *        C2 -> JC3
 *        C3 -> JD4
 *        C4 -> JC7
 *        C5 -> JD7
 *        C6 -> JD3
 *        C7 -> JD2
 *        C8 -> JD9
 */
class LedMatrixDriverIO extends Bundle {
  val rows = Input(UInt(8.W))
  val cols = Input(UInt(8.W))
  val orientation = Input(UInt(2.W))

  // PMOD JC: 8 physical pins
  val jc1  = Output(Bool())
  val jc2  = Output(Bool())
  val jc3  = Output(Bool())
  val jc4  = Output(Bool())
  val jc7  = Output(Bool())
  val jc8  = Output(Bool())
  val jc9  = Output(Bool())
  val jc10 = Output(Bool())

  // PMOD JD: 8 physical pins
  val jd1  = Output(Bool())
  val jd2  = Output(Bool())
  val jd3  = Output(Bool())
  val jd4  = Output(Bool())
  val jd7  = Output(Bool())
  val jd8  = Output(Bool())
  val jd9  = Output(Bool())
  val jd10 = Output(Bool())
}

class LedMatrixDriver extends RawModule {
  val io = IO(new LedMatrixDriverIO)

  // Orientation 1-4 selects the display rotation. 0 is treated as 1 (upright).
  val orient = Mux(io.orientation === 0.U, 0.U, io.orientation - 1.U)

  val r = io.rows
  val c = io.cols

  val rotatedRows = Mux(orient === 1.U, c,
                    Mux(orient === 2.U, Reverse(r),
                    Mux(orient === 3.U, Reverse(c), r)))

  val rotatedCols = Mux(orient === 1.U, Reverse(r),
                    Mux(orient === 2.U, Reverse(c),
                    Mux(orient === 3.U, r, c)))

  // Physical routing derived from empirical diagnostic observations.
  // Rows are Anodes (Active HIGH -> 1 = +3.3V)
  // Columns are Cathodes (Active LOW -> 0 = 0V / Ground)

  // PMOD JC Pins
  io.jc1  :=  rotatedRows(7)   // R8
  io.jc2  :=  rotatedRows(6)   // R7
  io.jc3  := !rotatedCols(1)   // C2
  io.jc4  :=  rotatedRows(0)   // R1
  io.jc7  := !rotatedCols(3)   // C4
  io.jc8  :=  rotatedRows(5)   // R6
  io.jc9  :=  rotatedRows(3)   // R4
  io.jc10 := !rotatedCols(0)   // C1

  // PMOD JD Pins
  io.jd1  :=  rotatedRows(4)   // R5
  io.jd2  := !rotatedCols(6)   // C7
  io.jd3  := !rotatedCols(5)   // C6
  io.jd4  := !rotatedCols(2)   // C3
  io.jd7  := !rotatedCols(4)   // C5
  io.jd8  :=  rotatedRows(1)   // R2
  io.jd9  := !rotatedCols(7)   // C8
  io.jd10 :=  rotatedRows(2)   // R3
}
