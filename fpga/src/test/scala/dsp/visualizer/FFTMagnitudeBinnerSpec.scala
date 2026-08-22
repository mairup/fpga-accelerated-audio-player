package dsp.visualizer

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

class FFTMagnitudeBinnerSpec extends AnyFlatSpec with Matchers with ChiselScalatestTester {

  val testFftSize = 1024
  val testBins    = 8

  def feedBin(dut: FFTMagnitudeBinner, re: Int, im: Int, isLast: Boolean = false): Unit = {
    dut.io.re.poke(re.S)
    dut.io.im.poke(im.S)
    dut.io.valid.poke(true.B)
    dut.io.frameDone.poke(isLast.B)
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
      dut.clock.setTimeout(0)
      dut.io.valid.poke(false.B)
      dut.io.frameDone.poke(false.B)

      for (i <- 0 until testFftSize) {
        val magnitude = if (i < testFftSize / 2) 200 else 0
        feedBin(dut, magnitude, 0, isLast = (i == testFftSize - 1))
      }

      dut.io.valid.poke(false.B)
      dut.io.frameDone.poke(false.B)

      dut.io.binValid.expect(true.B)

      val results = (0 until testBins).map(i => dut.io.binMagnitudes(i).peek().litValue.toInt)

      for (bin <- 0 until testBins) {
        withClue(s"bin[$bin] = ${results(bin)}: ") {
          results(bin) should be > 0
        }
      }
    }
  }

  it should "reset accumulators after frameDone" in {
    test(new FFTMagnitudeBinner(testFftSize, testBins, bitReversed = false)) { dut =>
      dut.clock.setTimeout(0)
      dut.io.valid.poke(false.B)
      dut.io.frameDone.poke(false.B)

      for (i <- 0 until testFftSize) feedBin(dut, 1000, 0, isLast = (i == testFftSize - 1))

      dut.io.valid.poke(false.B)
      dut.io.frameDone.poke(false.B)

      dut.io.binValid.expect(true.B)
      val firstFrame = (0 until testBins).map(i => dut.io.binMagnitudes(i).peek().litValue.toInt)
      firstFrame.exists(_ > 0) shouldBe true

      idle(dut)

      for (i <- 0 until testFftSize) feedBin(dut, 500, 0, isLast = (i == testFftSize - 1))

      dut.io.valid.poke(false.B)
      dut.io.frameDone.poke(false.B)

      val secondFrame = (0 until testBins).map(i => dut.io.binMagnitudes(i).peek().litValue.toInt)
      for (bin <- 0 until testBins) {
        withClue(s"bin[$bin] second frame should be less than first: ") {
          secondFrame(bin) should be < firstFrame(bin)
        }
      }
    }
  }

  it should "compute scaled squared magnitude correctly for negative inputs" in {
    test(new FFTMagnitudeBinner(testFftSize, testBins, bitReversed = false)) { dut =>
      dut.clock.setTimeout(0)
      dut.io.valid.poke(false.B)
      dut.io.frameDone.poke(false.B)

      feedBin(dut, -300, -400)
      for (i <- 1 until testFftSize) feedBin(dut, 0, 0, isLast = (i == testFftSize - 1))

      dut.io.valid.poke(false.B)
      dut.io.frameDone.poke(false.B)

      dut.io.binValid.expect(true.B)

      val bin0 = dut.io.binMagnitudes(0).peek().litValue.toInt
      // Alpha Max Plus Beta Min for (-300, -400): max(300, 400) + (300>>2) + (300>>3) = 400 + 75 + 37 = 512
      withClue(s"bin[0] should be 512: ") {
        bin0 shouldBe 512
      }
    }
  }
}
