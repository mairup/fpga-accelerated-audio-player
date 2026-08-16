# FFT Audio Visualizer Design Plan

## 1. Overview
The goal is to transform the incoming time-domain I2S audio stream into 8 frequency-domain categories. For each category, we will calculate the minimum and maximum volume (magnitude) observed over a sliding temporal window to provide data for an 8x8 LED matrix visualizer.

## 2. Hardware Requirements & IP Cores
- **Target FPGA**: Nexys A7-100T (Artix-7).
- **FFT IP**: Xilinx LogiCORE XFFT.
    - **Configuration**:
        - **Transform Length**: 512 or 1024 points (provides sufficient frequency resolution for an 8x8 grid).
        - **Input Type**: Real (single-channel audio).
        - **Output Type**: Complex (Real and Imaginary parts).
        - **Scaling**: Block Floating Point to prevent overflow during the butterfly stages.
- **Memory**: Dual-port BRAM for sample buffering and intermediate FFT storage.

## 3. Processing Pipeline

### Phase A: Data Acquisition & Windowing
1.  **Sample Buffer**: A BRAM-based circular buffer to collect $N$ samples from the `i2sController.io.pcmRx` stream.
2.  **Windowing Function**: A module to apply a **Hanning Window** to the samples before the FFT. This is critical to reduce spectral leakage between frequency bins.
    - $w(n) = 0.5 \cdot (1 - \cos(\frac{2\pi n}{N-1}))$

### Phase B: FFT & Magnitude Calculation
1.  **XFFT Core**: Processes the windowed samples in the frequency domain.
2.  **Magnitude Extraction**:
    - For each bin $k$, compute the magnitude $\text{Mag}(k)$.
    - *Optimization*: To avoid the high resource cost of a hardware square root, we will use the Manhattan distance approximation: $\text{Mag}(k) \approx |\text{Re}(k)| + |\text{Im}(k)|$.
3.  **Frequency Binning**:
    - The $N/2$ unique frequency bins will be divided into 8 equal groups (categories).
    - For each category $i \in [0, 7]$:
        - $\text{Category\_Volume}(i) = \sum_{k \in \text{Range}_i} \text{Mag}(k)$

### Phase C: Temporal Min/Max Tracking
To satisfy the requirement of tracking "MIN to MAX volume in any given moment", we implement a temporal tracking module:
1.  **Observation Window**: A timer (e.g., 500ms) defines the period for which we track extremes.
2.  **Tracking Logic**:
    - Every FFT frame, calculate the current $\text{Category\_Volume}(i)$.
    - Update the running extremes:
        - `current_max[i] = max(current_max[i], new_volume[i])`
        - `current_min[i] = min(current_min[i], new_volume[i])`
3.  **Window Reset/Decay**: Every $T$ ms, the values are reset or "leaked" towards the current volume to ensure the visualizer remains responsive to changing audio levels.

## 4. Interface to LED Controller
The `FFTAnalyzer` module will expose:
- `cat_max`: `Vec(8, UInt(16.W))` (The maximum magnitude seen in the window).
- `cat_min`: `Vec(8, UInt(16.W))` (The minimum magnitude seen in the window).
- `valid`: `Bool` (Pulse when a new Min/Max set is updated).

## 5. Implementation Steps
1.  **Step 1: `FFTAnalyzer` Chisel Module**: Create the top-level wrapper for buffering and windowing.
2.  **Step 2: XFFT Wrapper**: Create a Chisel wrapper for the Xilinx XFFT IP.
3.  **Step 3: Magnitude & Binning**: Implement the summation logic for the 8 categories.
4.  **Step 4: Min/Max Tracker**: Implement the temporal logic for tracking extremes.
5.  **Step 5: Integration**: Connect the `FFTAnalyzer` to the `TopAudioAccelerator` pipeline.
