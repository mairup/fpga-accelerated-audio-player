package fpga

import chisel3._

/** Physical 8x8 LED Matrix Driver.
 *
 *  Single source of truth for the physical pin mapping and polarity
 *  between logical (row, col) coordinates and Nexys A7 PMOD JC/JD headers.
 *
 *  Logical coordinates (both active-high):
 *    - rows(i) = 1 -> Row (i+1) is ACTIVE (cathode grounded to 0V)
 *    - cols(i) = 1 -> Column (i+1) is ACTIVE (anode driven high to 3.3V)
 */
class LedMatrixDriverIO extends Bundle {
  val rows = Input(UInt(8.W))
  val cols = Input(UInt(8.W))

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

  // Physical routing derived from empirical diagnostic observations.
  // Columns are Anodes (Active HIGH -> 1 = ON)
  // Rows are Cathodes (Active LOW  -> 0 = ON / Grounded)

  // PMOD JC Pins
  io.jc1  :=  io.cols(0)   // C1
  io.jc2  :=  io.cols(1)   // C2
  io.jc3  := !io.rows(1)   // R2
  io.jc4  :=  io.cols(7)   // C8
  io.jc7  := !io.rows(3)   // R4
  io.jc8  :=  io.cols(2)   // C3
  io.jc9  :=  io.cols(4)   // C5
  io.jc10 := !io.rows(0)   // R1

  // PMOD JD Pins
  io.jd1  := !io.rows(2)   // R3
  io.jd2  := !io.rows(5)   // R6
  io.jd3  := !io.rows(7)   // R8
  io.jd4  :=  io.cols(3)   // C4
  io.jd7  :=  io.cols(5)   // C6
  io.jd8  :=  io.cols(6)   // C7
  io.jd9  := !io.rows(6)   // R7
  io.jd10 := !io.rows(4)   // R5
}
