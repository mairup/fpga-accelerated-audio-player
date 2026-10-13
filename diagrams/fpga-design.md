# FPGA design — audio data flow

> Auto-generated from the Chisel sources by `generate_fpga_diagram.py`.
> Do not edit by hand; re-run the script to regenerate.
> Minimal view: audio-data path only (control/telemetry/implementation detail omitted).

```mermaid
flowchart TB
subgraph S_TopAudioAccelerator["TopAudioAccelerator"]
    subgraph S_audioPipeline["AudioPipeline"]
        chorus["Chorus"]
        overdrive["Overdrive"]
        tremolo["Tremolo"]
    end
    dac["SigmaDeltaDAC"]
    i2sController["I2sController"]
    matrixVisualizer["LedMatrixVisualizer"]
    visualizer["VisualizerTop"]
end
audioPipeline -- "SInt(32.W)" --> dac
chorus -- "SInt(32.W)" --> tremolo
i2sController -- "SInt(32.W)" --> audioPipeline
i2sController -- "SInt(32.W)" --> visualizer
overdrive -- "SInt(32.W)" --> chorus
visualizer -- "Vec(8, UInt(24.W))" --> matrixVisualizer
```
