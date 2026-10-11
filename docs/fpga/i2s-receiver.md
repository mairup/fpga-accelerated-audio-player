# I2S receiver

`I2sController` (`fpga/src/main/scala/fpga/I2sController.scala`) decodes the ESP32's I2S bus into 32-bit samples.

Inputs: `clk` (bit clock), `ws` (word select), `sdOut` (serial data). Outputs: `pcmRx` (SInt32), `pcmRxValid`.

## Behavior

1. `clk` and `ws` are double-synchronized; a rising `clk` edge and any `ws` edge are detected.
2. On a `ws` edge the bit counter resets and the channel is latched: `isLeftChannel = !ws`. (WS low = left, per the Philips I2S convention.)
3. On each rising `clk`, the counter increments. For counts 2–16 the data line is shifted into a 15-bit register, MSB-first.
4. At count 16 the register is left-shifted by one (16-bit value, LSB 0) and left-justified into a 32-bit Q31 word.
5. `pcmRxValid` pulses once per left-channel sample. Only the left channel is output (the stream is mono).

Philips I2S transmits the MSB one clock cycle after the `ws` transition; the FPGA skips that first cycle (counter = 1) and samples the following 15. So it captures 15 of the 16 transmitted bits per sample (the LSB is set to 0).
