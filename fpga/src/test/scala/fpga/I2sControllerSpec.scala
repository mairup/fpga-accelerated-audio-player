package fpga

import chisel3._
import chiseltest._
import chiseltest.chiselSim.AnySystemSim
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

class I2sControllerSpec extends AnyFlatSpec with Matchers with ChiselTest with AnySystemSim {
  behavior of "I2sController with alternating left/right"
  it should "mark samples on both ws polarities as valid" in {
    val controller = Module(new I2sController)
    var sawValidWithWsHigh = false
    var sawValidWithWsLow = false
    controller.io.sdOut := 1.B
    controller.io.bclk := 1.B
    for (i <- 0 until 96) {
      val wsHigh = (i / 24) % 2 == 0
      controller.io.ws := (if (wsHigh) 1.B else 0.B)
      controller.io.bclk := (if (i % 2 == 0) 0.B else 1.B)
      Step(1)
      if (controller.io.pcmRxValid.peekBoolean()) {
        if (wsHigh) sawValidWithWsHigh = true else sawValidWithWsLow = true
      }
    }
    sawValidWithWsHigh shouldBe true
    sawValidWithWsLow shouldBe true
  }
}
