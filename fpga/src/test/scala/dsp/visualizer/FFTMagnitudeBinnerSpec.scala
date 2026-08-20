package dsp.visualizer

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

class FFTMagnitudeBinnerSpec extends AnyFlatSpec with Matchers with ChiselScalatestTester {

  val testFftSize = 16
  val testBins    = 4

  def feedBin(dut: FFTMagnitudeBinner, re: Int, im: Int): Unit = {
    dut.io.re.poke(re.S)
    dut.io.im.poke(im.S)
    dut.io.valid.poke(true.B)
    dut.io.frameDone.poke(false.B)
    dut.clock.step(1)
  }

  def idle(dut: FFTMagnitudeBinner): Unit = {
    dut.io.valid.poke(false.B)
    dut.io.frameDone.poke(false.B)
    dut.clock.step(1)
  }

  behavior of "FFTMagnitudeBinner"

  it should "accumulate magnitudes into the correct bins (natural order)" in {
    test(new FFTMagnitudeBinner(testFftSize, testBins, bitReversed = false)) { dut =>
      dut.io.valid.poke(false.B)
      dut.io.frameDone.poke(false.B)

      for (i <- 0 until testFftSize) {
        val magnitude = if (i < testFftSize / 2) (i + 1) * 10 else 0
        feedBin(dut, magnitude, 0)
      }

      dut.io.valid.poke(false.B)
      dut.io.frameDone.poke(true.B)
      dut.clock.step(1)
      dut.io.frameDone.poke(false.B)

      dut.io.binValid.expect(true.B)

      val results = (0 until testBins).map(i => dut.io.binMagnitudes(i).peek().litValue.toInt)

      for (bin <- 0 until testBins) {
        withClue(s"bin[$bin] = ${results(bin)}: ") {
          results(bin) should be > 0
        }
      }

      results(0) should be < results(testBins - 1)
    }
  }

  it should "reset accumulators after frameDone" in {
    test(new FFTMagnitudeBinner(testFftSize, testBins, bitReversed = false)) { dut =>
      dut.io.valid.poke(false.B)
      dut.io.frameDone.poke(false.B)

      for (_ <- 0 until testFftSize) feedBin(dut, 1000, 0)

      dut.io.valid.poke(false.B)
      dut.io.frameDone.poke(true.B)
      dut.clock.step(1)
      dut.io.frameDone.poke(false.B)

      dut.io.binValid.expect(true.B)
      val firstFrame = (0 until testBins).map(i => dut.io.binMagnitudes(i).peek().litValue.toInt)
      firstFrame.exists(_ > 0) shouldBe true

      idle(dut)

      for (_ <- 0 until testFftSize) feedBin(dut, 500, 0)

      dut.io.valid.poke(false.B)
      dut.io.frameDone.poke(true.B)
      dut.clock.step(1)
      dut.io.frameDone.poke(false.B)

      val secondFrame = (0 until testBins).map(i => dut.io.binMagnitudes(i).peek().litValue.toInt)
      for (bin <- 0 until testBins) {
        withClue(s"bin[$bin] second frame should be less than first: ") {
          secondFrame(bin) should be < firstFrame(bin)
        }
      }
    }
  }

  it should "compute Manhattan magnitude correctly for negative inputs" in {
    test(new FFTMagnitudeBinner(testFftSize, testBins, bitReversed = false)) { dut =>
      dut.io.valid.poke(false.B)
      dut.io.frameDone.poke(false.B)

      feedBin(dut, -300, -400)
      for (_ <- 1 until testFftSize) feedBin(dut, 0, 0)

      dut.io.valid.poke(false.B)
      dut.io.frameDone.poke(true.B)
      dut.clock.step(1)
      dut.io.frameDone.poke(false.B)

      dut.io.binValid.expect(true.B)

      val bin0 = dut.io.binMagnitudes(0).peek().litValue.toInt
      withClue(s"bin[0] should be |(-300)| + |(-400)| = 700: ") {
        bin0 shouldBe 700
      }
    }
  }
}
