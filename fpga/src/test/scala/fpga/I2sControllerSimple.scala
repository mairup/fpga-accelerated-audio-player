import chisel3._
import chiseltest._
import chiseltest.chiselSim.AnySystemSim
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

class I2sControllerSimpleSpec extends AnyFlatSpec with Matchers with ChiselTest with AnySystemSim {
  "I2sController" should "only mark left-channel samples as valid" in {
    val controller = Module(new I2sController)
    val wsPattern = Seq(1.B, 0.B, 1.B, 0.B)  // alternating L/R
    for (ws <- wsPattern) {
      controller.io.ws := ws
      Step(8)
      val expectedValid = (ws === 1.B)
      controller.io.pcmRxValid shouldBe expectedValid
    }
  }
}
