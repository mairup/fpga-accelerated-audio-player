# Sigma-delta DAC

`SigmaDeltaDAC` (`fpga/src/main/scala/fpga/SigmaDeltaDAC.scala`) converts a 32-bit sample stream into a 1-bit pulse-density (PDM) signal, which drives the PWM audio outputs directly.

## Behavior

1. **Offset to unsigned**: the signed sample is converted to unsigned by adding 2^31, so silence (0) maps to 0x80000000 (50% duty cycle).
2. **Interpolation**: between sample updates the output ramps toward the next sample. `stepDelta = (target - current) >> 11` (~2048 steps across the 100 MHz / 48 kHz ≈ 2083-clock sample period).
3. **First-order sigma-delta / phase accumulator**: a 33-bit accumulator adds the current sample value every clock; its carry-out bit is the 1-bit PDM output.

The 1-bit stream is low-pass filtered by the external speaker/RC network into analog audio. All four audio output pins carry this same signal (see [Hardware pin map](../hardware-pinmap.md)).
