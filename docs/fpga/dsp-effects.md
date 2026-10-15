# DSP effects

Effect chain in `AudioPipeline` (`fpga/src/main/scala/dsp/AudioPipeline.scala`): overdrive → chorus → tremolo. Each stage is gated by a switch and by-passed with a mux when disabled: `enableX = swFxMaster && swX`.

All math is Q31 fixed point (`dsp/NumberTypeUtils.scala`): 32-bit signed, 31 fractional bits, value range [-1, 1).

## Overdrive — `dsp/Overdrive.scala`

Gain 7× followed by hard clipping at ±0.2.

1. `sampleIn * 7` (gain constant 7.0).
2. If `|result| > 0.2`, output is clamped to ±0.2; otherwise output is the gained sample.

This is hard-clip distortion (no lookup table).

## Chorus — `dsp/Chorus.scala`

A modulated delay line mixed 50/50 with the dry signal.

- Delay buffer: 4096 samples (dual-port BRAM RAM).
- Center delay 50 ms (2400 samples), swept ±10 ms (480 samples) by a sine LFO at 0.25 Hz (512-entry sine ROM).
- The delayed ("wet") signal is low-pass smoothed (one-pole: 0.25·new + 0.75·prev).
- Output = 0.5·dry + 0.5·wet.

## Tremolo — `dsp/Tremolo.scala`

Amplitude modulation by a triangle LFO.

- LFO: 5 Hz triangle (24-bit phase accumulator).
- Depth 0.9 → gain sweeps between 10% and 100% (envelope 25–255 out of 256).
- The top 24 bits of the sample are multiplied by the envelope (one DSP48 slice), saturated to 32 bits.

## Fixed-point helpers — `dsp/NumberTypeUtils.scala`

- `multQ31`: 32×32 → round → `>> 31`, saturated.
- `addQ31` / `subQ31`: saturating add/subtract.
- `doubleToQ31BigInt`: converts a double to a Q31 constant.
