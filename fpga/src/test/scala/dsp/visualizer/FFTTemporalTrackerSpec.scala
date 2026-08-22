package dsp.visualizer

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

class FFTTemporalTrackerSpec extends AnyFlatSpec with Matchers with ChiselScalatestTester {

  val testBins  = 4
  val testWidth = 24

  def feedFrame(dut: FFTTemporalTracker, magnitudes: Seq[Int]): Unit = {
    for (i <- 0 until dut.numBins) {
      dut.io.binMagnitudes(i).poke(magnitudes(i).U)
    }
    dut.io.valid.poke(true.B)
    dut.clock.step(1)
    dut.io.valid.poke(false.B)
  }

  behavior of "FFTTemporalTracker"

  it should "output zeros initially" in {
    test(new FFTTemporalTracker(testBins, testWidth)) { dut =>
      dut.io.valid.poke(false.B)
      for (i <- 0 until testBins) dut.io.binMagnitudes(i).poke(0.U)

      for (_ <- 0 until 5) {
        dut.io.newUpdate.expect(false.B)
        for (i <- 0 until testBins) {
          dut.io.catVolume(i).expect(0.U)
        }
        dut.clock.step(1)
      }
    }
  }

  it should "jump immediately on fast attack and assert newUpdate" in {
    test(new FFTTemporalTracker(testBins, testWidth)) { dut =>
      dut.io.valid.poke(false.B)
      for (i <- 0 until testBins) dut.io.binMagnitudes(i).poke(0.U)
      dut.clock.step(1)

      feedFrame(dut, Seq(500, 200, 300, 800))

      dut.io.catVolume(0).expect(500.U)
      dut.io.catVolume(1).expect(200.U)
      dut.io.catVolume(2).expect(300.U)
      dut.io.catVolume(3).expect(800.U)
    }
  }

  it should "exponentially decay by 25% on subsequent lower frames" in {
    test(new FFTTemporalTracker(testBins, testWidth)) { dut =>
      dut.io.valid.poke(false.B)
      for (i <- 0 until testBins) dut.io.binMagnitudes(i).poke(0.U)
      dut.clock.step(1)

      // Initial peak of 1000
      feedFrame(dut, Seq(1000, 1000, 1000, 1000))
      dut.io.catVolume(0).expect(1000.U)

      // Next frame with 0 input: decay by 25% (1000 - 250 = 750)
      feedFrame(dut, Seq(0, 0, 0, 0))
      dut.io.catVolume(0).expect(750.U)

      // Next frame: 750 - (750 >> 2) = 750 - 187 = 563
      feedFrame(dut, Seq(0, 0, 0, 0))
      dut.io.catVolume(0).expect(563.U)
    }
  }
}
