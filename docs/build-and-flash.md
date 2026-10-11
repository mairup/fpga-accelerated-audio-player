# Build & flash

Three artifacts, three toolchains. FPGA bitstream via Docker (F4PGA), ESP32 firmware via Toit Jaguar, client via plain Python.

## FPGA bitstream

Top-level `make fpga` builds and flashes; `make fpga build` and `make fpga flash` split it. Targets defined in `Makefile` (root) and `fpga/Makefile`.

Build runs inside the `fpga-builder` Docker image (`fpga/Dockerfile.builder`: Ubuntu 22.04 + JDK 21 + sbt 1.9.9 + Miniconda `xc7` env with yosys/nextpnr/prjxray/f4pga). Steps, from `fpga/scripts/build_in_container.sh`:

1. `sbt runMain fpga.TopAudioAcceleratorApp` — Chisel emits `TopAudioAccelerator.v`.
2. `yosys -p "synth_xilinx -flatten -top TopAudioAccelerator"` → JSON netlist.
3. `nextpnr-xilinx --chipdb …/xc7a100tcsg324-1.bin` — place & route (`--placer heap`, timing failures allowed) → FASM.
4. `scripts/assemble_fasm.py` → frame file, then `xc7frames2bit` → `TopAudioAccelerator.bit`.

Target part is `xc7a100tcsg324-1` (Nexys A7 100T).

Flash: `openFPGALoader -b nexys_a7_100 TopAudioAccelerator.bit`.

- `make build-images` — builds the `fpga-builder` and `fpga-flasher` images.
- `make deploy` — build + flash.
- `make clean` — removes generated Verilog/netlist/bitstream artifacts.

## ESP32 firmware

`make esp` runs `jag run -d <device> esp/audio_streamer.toit`. Default device `nervous-bother`; override with `ESP_DEVICE=…`.

## Client

`make client` runs `client/audio_client.py --target 192.168.5.73`. `make client usb` uses USB serial. See [Client](client/audio-client.md).

## Toolchain versions

- Scala 2.13.13, Chisel 3.6.1, chiseltest 0.6.1 (`fpga/build.sbt`, `fpga/project/build.properties` sbt 1.9.9)
- Toit via Jaguar (`jag`)
- openFPGALoader for flashing
