package fpga

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

class JaFreqDriverSpec extends AnyFlatSpec with Matchers with ChiselScalatestTester {
  "JaFreqDriver" should "generate correct frequencies on all 8 JA pins when cpuResetN is high" in {
    val simClockHz = 256

    test(new JaFreqDriver(simClockHz)) { dut =>
      dut.io.cpuResetN.poke(true.B)

      var prevJa1 = false
      var prevJa2 = false
      var prevJa3 = false
      var prevJa4 = false
      var prevJa7 = false
      var prevJa8 = false
      var prevJa9 = false
      var prevJa10 = false

      var countJa1 = 0
      var countJa2 = 0
      var countJa3 = 0
      var countJa4 = 0
      var countJa7 = 0
      var countJa8 = 0
      var countJa9 = 0
      var countJa10 = 0

      for (_ <- 0 until simClockHz) {
        val currJa1 = dut.io.ja1.peek().litToBoolean
        val currJa2 = dut.io.ja2.peek().litToBoolean
        val currJa3 = dut.io.ja3.peek().litToBoolean
        val currJa4 = dut.io.ja4.peek().litToBoolean
        val currJa7 = dut.io.ja7.peek().litToBoolean
        val currJa8 = dut.io.ja8.peek().litToBoolean
        val currJa9 = dut.io.ja9.peek().litToBoolean
        val currJa10 = dut.io.ja10.peek().litToBoolean

        if (currJa1 && !prevJa1) countJa1 += 1
        if (currJa2 && !prevJa2) countJa2 += 1
        if (currJa3 && !prevJa3) countJa3 += 1
        if (currJa4 && !prevJa4) countJa4 += 1
        if (currJa7 && !prevJa7) countJa7 += 1
        if (currJa8 && !prevJa8) countJa8 += 1
        if (currJa9 && !prevJa9) countJa9 += 1
        if (currJa10 && !prevJa10) countJa10 += 1

        prevJa1 = currJa1
        prevJa2 = currJa2
        prevJa3 = currJa3
        prevJa4 = currJa4
        prevJa7 = currJa7
        prevJa8 = currJa8
        prevJa9 = currJa9
        prevJa10 = currJa10

        dut.clock.step(1)
      }

      countJa1 shouldBe 1
      countJa2 shouldBe 2
      countJa3 shouldBe 4
      countJa4 shouldBe 8
      countJa7 shouldBe 16
      countJa8 shouldBe 32
      countJa9 shouldBe 64
      countJa10 shouldBe 128
    }
  }
}
