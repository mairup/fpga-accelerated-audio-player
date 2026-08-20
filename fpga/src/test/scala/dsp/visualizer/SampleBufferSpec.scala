package dsp.visualizer

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

class SampleBufferSpec extends AnyFlatSpec with Matchers with ChiselScalatestTester {

  val testDepth = 16

  behavior of "SampleBuffer"

  it should "stay idle and not burst until the buffer is full" in {
    test(new SampleBuffer(testDepth)) { dut =>
      dut.io.sampleValid.poke(false.B)

      for (_ <- 0 until 10) {
        dut.io.burstValid.expect(false.B)
        dut.clock.step(1)
      }
    }
  }

  it should "accumulate samples then burst all of them out in order" in {
    test(new SampleBuffer(testDepth)) { dut =>
      dut.io.sampleValid.poke(false.B)

      for (i <- 0 until testDepth) {
        dut.io.sampleIn.poke((i + 100).S)
        dut.io.sampleValid.poke(true.B)
        dut.clock.step(1)
      }

      dut.io.sampleValid.poke(false.B)
      dut.clock.step(1)

      var burstSamples = Seq.empty[Int]
      var burstDoneSeen = false

      for (_ <- 0 until testDepth + 5) {
        if (dut.io.burstValid.peek().litToBoolean) {
          burstSamples = burstSamples :+ dut.io.burstOut.peek().litValue.toInt
        }
        if (dut.io.burstDone.peek().litToBoolean) {
          burstDoneSeen = true
        }
        dut.clock.step(1)
      }

      burstDoneSeen shouldBe true
      withClue(s"got ${burstSamples.length} samples, expected $testDepth: ") {
        burstSamples.length shouldBe testDepth
      }
      for (i <- burstSamples.indices) {
        withClue(s"sample[$i]: ") {
          burstSamples(i) shouldBe (i + 100)
        }
      }
    }
  }

  it should "signal burstDone exactly once per burst" in {
    test(new SampleBuffer(testDepth)) { dut =>
      dut.io.sampleValid.poke(false.B)

      for (i <- 0 until testDepth) {
        dut.io.sampleIn.poke(i.S)
        dut.io.sampleValid.poke(true.B)
        dut.clock.step(1)
      }
      dut.io.sampleValid.poke(false.B)
      dut.clock.step(1)

      var doneCount = 0
      for (_ <- 0 until testDepth + 10) {
        if (dut.io.burstDone.peek().litToBoolean) doneCount += 1
        dut.clock.step(1)
      }

      doneCount shouldBe 1
    }
  }
}
