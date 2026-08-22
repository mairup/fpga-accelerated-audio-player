package dsp.visualizer

import chisel3._
import chisel3.util._
import fpga.LedMatrixDriver

class LedMatrixVisualizerIO extends Bundle {
  val bandMagnitudes = Input(Vec(8, UInt(24.W)))

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

/** 8x8 LED Matrix Audio Spectrum Visualizer.
 *
 *  Takes 8-band smoothed FFT magnitudes, normalizes them across octave frequency bands,
 *  multiplexes rows at 1 kHz full frame refresh (8 kHz row scan), and routes
 *  anodes and cathodes through LedMatrixDriver to PMOD JC & JD.
 *
 *  @param clockFreqHz Clock frequency in Hz (default 100 MHz)
 *  @param frameRefreshHz Full frame refresh rate in Hz (default 1000 Hz)
 *  @param orientation Fixed compile-time orientation (1 = upright, 2 = 90 deg CW, 3 = 180 deg, 4 = 270 deg CW)
 */
class LedMatrixVisualizer(
  val clockFreqHz:    Int = 100_000_000,
  val frameRefreshHz: Int = 1000,
  val orientation:    Int = 1
) extends Module {
  val io = IO(new LedMatrixVisualizerIO)

  // 1. Multiplexing Refresh Counter: 100MHz / (1000 * 8) = 12,500 cycles per row tick
  val rowRefreshHz  = frameRefreshHz * 8
  val refreshCycles = clockFreqHz / rowRefreshHz
  val refreshDiv    = RegInit(0.U(log2Ceil(refreshCycles).W))
  val rowStrobe     = WireDefault(false.B)

  when(refreshDiv === (refreshCycles - 1).U) {
    refreshDiv := 0.U
    rowStrobe  := true.B
  }.otherwise {
    refreshDiv := refreshDiv + 1.U
  }

  val activeRow = RegInit(0.U(3.W))
  when(rowStrobe) {
    activeRow := activeRow + 1.U
  }

  // 2. Map 8 FFT Frequency Bands to Bar Heights (0 to 8 LEDs high)
  // Per-band normalization shift compensating for natural 1/f audio spectral distribution
  def quantizeBand(magnitude: UInt, bandIdx: Int): UInt = {
    val shift = bandIdx match {
      case 0 => 0
      case 1 => 0
      case 2 => 1
      case 3 => 2
      case 4 => 3
      case 5 => 4
      case 6 => 5
      case _ => 6
    }
    val norm = magnitude >> shift.U
    Mux(norm >= 512.U, 8.U,
    Mux(norm >= 256.U, 7.U,
    Mux(norm >= 128.U, 6.U,
    Mux(norm >= 64.U,  5.U,
    Mux(norm >= 32.U,  4.U,
    Mux(norm >= 16.U,  3.U,
    Mux(norm >= 8.U,   2.U,
    Mux(norm >= 4.U,   1.U, 0.U))))))))
  }

  val bandLevels = VecInit((0 until 8).map(i => quantizeBand(io.bandMagnitudes(i), i)))

  // 3. Compute Column Anode values for the currently active row
  val colAnodes = Wire(Vec(8, Bool()))
  for (col <- 0 until 8) {
    colAnodes(col) := bandLevels(col) > activeRow
  }

  // 4. Physical matrix driver for Nexys A7 PMOD JC/JD wiring
  val driver = Module(new LedMatrixDriver)
  driver.io.rows := (1.U(8.W) << activeRow)
  driver.io.cols := colAnodes.asUInt
  driver.io.orientation := orientation.U(2.W)

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
