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
      // Alpha Max Plus Beta Min for (-300, -400): 400 + 75 + 37 = 512
      // In peak-weighted mode: mean = 512 / BandBinCounts(0), peak = 512
      //   blended = mean + (peak - mean) * PeakBlendMult / 256
      val mean        = (512 * VisualizerConfig.BandDivMultipliers(0)) >> 16
      val diff        = 512 - mean
      val expectedBin0 = if (VisualizerConfig.PeakBlendMult >= 256) 512
                         else if (VisualizerConfig.PeakBlendMult <= 0) mean
                         else mean + ((diff * VisualizerConfig.PeakBlendMult) >> 8)
      withClue(s"bin[0] should be $expectedBin0 (blended): ") {
        bin0 shouldBe expectedBin0
      }
    }
  }

  it should "not boost a flat noise floor (peak = mean -> diff = 0)" in {
    test(new FFTMagnitudeBinner(testFftSize, testBins, bitReversed = false)) { dut =>
      dut.clock.setTimeout(0)
      dut.io.valid.poke(false.B)
      dut.io.frameDone.poke(false.B)

      // Feed all bins with the same constant magnitude: peak == mean in each band
      val flatMag = 200
      for (i <- 0 until testFftSize) feedBin(dut, flatMag, 0, isLast = (i == testFftSize - 1))

      dut.io.valid.poke(false.B)
      dut.io.frameDone.poke(false.B)
      dut.io.binValid.expect(true.B)

      for (band <- 0 until testBins) {
        val result = dut.io.binMagnitudes(band).peek().litValue.toInt
        val n      = VisualizerConfig.BandBinCounts(band)
        val mult   = VisualizerConfig.BandDivMultipliers(band)
        // Sum = flatMag * n bins; average = (flatMag * n * mult) >> 16 ≈ flatMag (rounding)
        val mean   = ((flatMag.toLong * n * mult) >> 16).toInt
        // When all bins equal flatMag: peak == mean → diff == 0 → blended == mean (no boost)
        withClue(s"band[$band]: flat noise floor should not be boosted (got $result, mean $mean): ") {
          result shouldBe mean
        }
      }
    }
  }

  it should "boost an isolated transient (peak >> mean)" in {
    test(new FFTMagnitudeBinner(testFftSize, testBins, bitReversed = false)) { dut =>
      dut.clock.setTimeout(0)
      dut.io.valid.poke(false.B)
      dut.io.frameDone.poke(false.B)

      // Feed one loud bin at index 0 (band 0), rest silent
      val peakMag = 2000
      feedBin(dut, peakMag, 0)
      for (i <- 1 until testFftSize) feedBin(dut, 0, 0, isLast = (i == testFftSize - 1))

      dut.io.valid.poke(false.B)
      dut.io.frameDone.poke(false.B)
      dut.io.binValid.expect(true.B)

      val bin0   = dut.io.binMagnitudes(0).peek().litValue.toInt
      val mult   = VisualizerConfig.BandDivMultipliers(0)
      val mean   = (peakMag * mult) >> 16
      val diff   = peakMag - mean
      val blended = if (VisualizerConfig.PeakBlendMult >= 256) peakMag
                    else if (VisualizerConfig.PeakBlendMult <= 0) mean
                    else mean + ((diff * VisualizerConfig.PeakBlendMult) >> 8)

      withClue(s"band[0] transient: got $bin0, expected $blended (mean=$mean, peak=$peakMag): ") {
        bin0 shouldBe blended
      }
      withClue(s"band[0] blended should be > mean ($mean): ") {
        bin0 should be > mean
      }
      withClue(s"band[0] blended should be <= peak ($peakMag): ") {
        bin0 should be <= peakMag
      }
    }
  }
}
