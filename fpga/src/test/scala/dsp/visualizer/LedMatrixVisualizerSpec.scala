package dsp.visualizer

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

class LedMatrixVisualizerSpec extends AnyFlatSpec with Matchers with ChiselScalatestTester {

  behavior of "LedMatrixVisualizer"

  it should "multiplex rows and drive column anodes according to FFT band magnitudes" in {
    // Clock 800 Hz with frame refresh 10 Hz -> 80 Hz row scan -> 10 clock cycles per row slot
    test(new LedMatrixVisualizer(clockFreqHz = 800, frameRefreshHz = 10, orientation = 1)) { dut =>
      // Set explicit 24-bit band magnitudes
      for (i <- 0 until 8) {
        dut.io.bandMagnitudes(i).poke(0.U(24.W))
      }
      // Band 0: high magnitude (50,000) -> reaches maximum level 8 (active across all rows 0..7)
      dut.io.bandMagnitudes(0).poke(50000.U(24.W))
      // Band 2: zero magnitude -> level 0 (inactive across all rows)
      dut.io.bandMagnitudes(2).poke(0.U(24.W))

      // --- Slot 0: Active Row 0 ---
      // R1 (activeRow 0) -> JC4 should be HIGH
      dut.io.jc4.expect(true.B)
      // Other rows should be LOW
      dut.io.jd8.expect(false.B)  // R2
      dut.io.jd10.expect(false.B) // R3

      // C1 (band 0 level 8 > 0) -> active -> JC10 is LOW (Cathode Active LOW)
      dut.io.jc10.expect(false.B)
      // C3 (band 2 level 0 not > 0) -> inactive -> JD4 is HIGH (Cathode Inactive HIGH)
      dut.io.jd4.expect(true.B)

      // Step 9 cycles: active row should remain 0 throughout the slot
      dut.clock.step(9)
      dut.io.jc4.expect(true.B)
      dut.io.jd8.expect(false.B)

      // Step 1 more cycle (10 cycles total) -> advances to Active Row 1
      dut.clock.step(1)
      dut.io.jc4.expect(false.B) // R1 is now inactive
      dut.io.jd8.expect(true.B)  // R2 is now active

      // Step 5 more row slots (50 cycles) -> advance to Active Row 6 (index 6)
      dut.clock.step(50)
      // R7 (activeRow 6) -> JC2 should be HIGH
      dut.io.jc2.expect(true.B)
      // C1 (band 0 level 8 > 6) -> active -> JC10 is LOW
      dut.io.jc10.expect(false.B)
      // C3 (band 2 level 0 not > 6) -> inactive -> JD4 is HIGH
      dut.io.jd4.expect(true.B)
    }
  }
}
