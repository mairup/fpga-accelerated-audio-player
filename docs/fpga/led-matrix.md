# LED matrix

Two modules drive the 8×8 LED matrix: `LedMatrixVisualizer` (multiplexing) and `LedMatrixDriver` (pin routing).

## LedMatrixVisualizer — `dsp/visualizer/LedMatrixVisualizer.scala`

- Maps the 8 band magnitudes to 8 bar heights (0–8 LEDs) via `VisualizerConfig.quantizeToLevel`.
- Multiplexes one row at a time: full frame at 1 kHz → row scan at 8 kHz (12,500 clock cycles per row at 100 MHz).
- For the active row, a column is lit when `bandLevels[col] > activeRow`.

## LedMatrixDriver — `fpga/LedMatrixDriver.scala`

Routes logical (row, col) to physical PMOD JC/JD pins, with an orientation rotation (0/90/180/270°, fixed at build time; the top uses 0).

- Rows are anodes (active high), columns are cathodes (active low).
- Exact pin assignments: [Hardware pin map](../hardware-pinmap.md).
