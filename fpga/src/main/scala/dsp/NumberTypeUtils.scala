package dsp

import chisel3._
import chisel3.util._

object FixedPointQ31 {

  val FractionalBits = 31
  val DataWidth = 32

  def fromInt16(sample: SInt): SInt = {
    (sample << 16).asSInt
  }

  def toInt16(sampleQ31: SInt): SInt = {
    val rounding = (1.S << 15)
    val rounded = sampleQ31 + Mux(sampleQ31 >= 0.S, rounding, -rounding)
    val shifted = rounded >> 16
    saturateSInt(shifted, 16)
  }

  def saturateSInt(input: SInt, targetWidth: Int): SInt = {
    val maxVal = ((1L << (targetWidth - 1)) - 1L).S
    val minVal = (-(1L << (targetWidth - 1))).S

    Mux(input > maxVal,
      maxVal,
      Mux(input < minVal,
        minVal,
        input.pad(targetWidth)(targetWidth - 1, 0).asSInt
      )
    )
  }

  def multQ31(a: SInt, b: SInt): SInt = {
    val wide = a * b
    val rounding = (1.S << 30)
    val rounded = wide + Mux(wide >= 0.S, rounding, -rounding)
    val shifted = rounded >> 31
    saturateSInt(shifted, 32)
  }

  def addQ31(a: SInt, b: SInt): SInt = {
    val wide = a +& b
    saturateSInt(wide, 32)
  }

  def subQ31(a: SInt, b: SInt): SInt = {
    val wide = a -& b
    saturateSInt(wide, 32)
  }

  def doubleToQ31BigInt(d: Double): BigInt = {
    val clamped = Math.max(-1.0, Math.min(1.0 - 1.0 / (1L << 31).toDouble, d))
    BigInt(Math.round(clamped * (1L << 31).toDouble))
  }

  def fromDouble(d: Double): SInt = {
    doubleToQ31BigInt(d).S(32.W)
  }

  def q31ToDouble(q31: BigInt): Double = {
    q31.toDouble / (1L << 31).toDouble
  }
}
