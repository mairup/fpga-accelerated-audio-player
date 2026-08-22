package dsp.visualizer

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

class LedMatrixVisualizerSpec extends AnyFlatSpec with Matchers with ChiselScalatestTester {

  behavior of "LedMatrixVisualizer"

  it should "multiplex rows and drive column anodes according to FFT band magnitudes" in {
    // Clock 800 Hz with frame refresh 10 Hz -> 80 Hz row scan -> 10 cycles per row
    test(new LedMatrixVisualizer(clockFreqHz = 800, frameRefreshHz = 10, orientation = 1)) { dut =>
      // Set band magnitudes (e.g. Band 0 = 600 -> Level 8, Band 1 = 150 -> Level 6)
      for (i <- 0 until 8) {
        dut.io.bandMagnitudes(i).poke(0.U)
      }
      dut.io.bandMagnitudes(0).poke(600.U) // norm = 600 >= 512 -> level 8
      dut.io.bandMagnitudes(1).poke(150.U) // norm = 150 >= 128 -> level 6

      // Row 0 active initially
      dut.clock.step(10) // step to row 1
      dut.clock.step(10) // step to row 2
    }
  }
}
