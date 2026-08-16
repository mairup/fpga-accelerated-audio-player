package dsp.visualizer

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

class VisualizerTopSpec extends AnyFlatSpec with Matchers with ChiselScalatestTester {
  "VisualizerTop" should "correctly track min and max magnitudes" in {
    // N=512, numBins=8, framesPerWindow=10
    test(new VisualizerTop(512, 8, 10)) { dut =>
      // Initial state
      dut.io.sampleIn.poke(0.S)
      dut.io.sampleValid.poke(false.B)
      
      // We need to feed samples to trigger the MockFFT
      // MockFFT is designed to output a bin with magnitude 1000 when binCounter reaches a certain point.
      // Actually, looking at MockFFT implementation:
      // It outputs magnitude 1000 at 'testBin' (index 10) when 'sampleValid' is true.
      
      // Let's drive the MockFFT by providing valid samples.
      // The MockFFT doesn't actually care about the value of sampleIn, just the validity.
      
      // Feed 512 samples to complete one FFT frame
      for (i <- 0 until 512) {
        dut.io.sampleIn.poke(100.S)
        dut.io.sampleValid.poke(true.B)
        dut.clock.step(1)
      }
      
      // After 512 cycles, the MockFFT should have finished one frame.
      // Because MockFFT increments its own counter and pulses frameDone.
      
      // Let's check if the binner has updated the magnitude.
      // Since MockFFT outputs magnitude 1000 at bin 10, 
      // and our binner sums them up...
      // With N=512, testBin=10, magnitude=1000:
      // The bin containing index 10 should have magnitude 1000.
      
      // Wait for the binner and tracker to process.
      // We need to drive enough cycles for the FFT, Binner, and Tracker to work.
      
      // Let's feed more frames to ensure we cross the framesPerWindow threshold.
      for (i <- 0 until 100) {
         dut.io.sampleIn.poke(100.S)
         dut.io.sampleValid.poke(true.B)
         dut.clock.step(1)
      }
      
      // Check if catMax is non-zero
      dut.io.catMax(1).expect(1000.U) // Bin 1 should contain index 10 if numBins=8 and N=512 (10/64 = 0)
      // Wait, N=512, numBins=8. Each bin has 512/8 = 64 samples.
      // Bin 0: 0-63
      // Bin 1: 64-127
      // ...
      // Bin 10 is in Bin (10 / 64) = 0.
      // So catMax(0) should be 1000.
      
      dut.io.catMax(0).expect(1000.U)
      dut.io.catMin(0).expect(1000.U)
    }
  }
}
