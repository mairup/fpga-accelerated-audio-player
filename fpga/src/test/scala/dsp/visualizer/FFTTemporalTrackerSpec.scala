package dsp.visualizer

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

class FFTTemporalTrackerSpec extends AnyFlatSpec with Matchers with ChiselScalatestTester {

  val testBins   = 4
  val testWindow = 4

  def feedFrame(dut: FFTTemporalTracker, magnitudes: Seq[Int]): Unit = {
    for (i <- 0 until dut.numBins) {
      dut.io.binMagnitudes(i).poke(magnitudes(i).U)
    }
    dut.io.valid.poke(true.B)
    dut.clock.step(1)
    dut.io.valid.poke(false.B)
  }

  behavior of "FFTTemporalTracker"

  it should "output zeros before the first window completes" in {
    test(new FFTTemporalTracker(testBins, testWindow)) { dut =>
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

  it should "latch peak values after framesPerWindow frames" in {
    test(new FFTTemporalTracker(testBins, testWindow)) { dut =>
      dut.io.valid.poke(false.B)
      for (i <- 0 until testBins) dut.io.binMagnitudes(i).poke(0.U)
      dut.clock.step(1)

      feedFrame(dut, Seq(100, 200, 300, 400))
      feedFrame(dut, Seq(500, 100, 100, 100))
      feedFrame(dut, Seq(50,  50,  50,  50))

      for (i <- 0 until testBins) dut.io.catVolume(i).expect(0.U)

      feedFrame(dut, Seq(10, 10, 10, 800))

      dut.io.newUpdate.expect(true.B)
      dut.io.catVolume(0).expect(500.U)
      dut.io.catVolume(1).expect(200.U)
      dut.io.catVolume(2).expect(300.U)
      dut.io.catVolume(3).expect(800.U)
    }
  }

  it should "reset peaks after each window" in {
    test(new FFTTemporalTracker(testBins, testWindow)) { dut =>
      dut.io.valid.poke(false.B)
      for (i <- 0 until testBins) dut.io.binMagnitudes(i).poke(0.U)
      dut.clock.step(1)

      for (_ <- 0 until testWindow) {
        feedFrame(dut, Seq(1000, 1000, 1000, 1000))
      }

      dut.io.catVolume(0).expect(1000.U)

      for (_ <- 0 until testWindow) {
        feedFrame(dut, Seq(50, 50, 50, 50))
      }

      dut.io.catVolume(0).expect(50.U)
    }
  }
}
