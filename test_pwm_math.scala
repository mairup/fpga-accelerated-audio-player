object TestPWM {
  def main(args: Array[String]): Unit = {
    def clamp(v: Long): Long = {
      if (v < 0) 0 else if (v > 1023) 1023 else v
    }
    
    val samples = Seq(-2147483648L, -1073741824L, 0L, 1073741824L, 2147483647L)
    
    for (s <- samples) {
      val shifted = (s + 2097152L) >> 22
      val biased = shifted + 512L
      val clamped = clamp(biased)
      println(f"In: $s%12d -> shifted: $shifted%6d -> biased: $biased%6d -> clamped: $clamped%6d")
    }
  }
}
