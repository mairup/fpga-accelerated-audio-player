#!/usr/bin/env bash
set -e

export F4PGA_INSTALL_DIR=/opt/f4pga
export PATH=/opt/conda/envs/xc7/bin:/usr/local/sbt/bin:$PATH

TOP="${TOP:-TopAudioAccelerator}"
XDC="${XDC:-constraints/nexys_a7_100.xdc}"

echo "=== Step 0: Cleaning Old Build Artifacts ==="
rm -f "$TOP.fasm" "$TOP.frames" "$TOP.bit" "$TOP.json" HelloWorld.v HelloWorld.bit TopAudioAccelerator.v LedMatrixDiagnosticTop.v LedMatrixTestTop.v DualPort*.v

echo "=== Step 1: Scala Chisel Verilog Generation ==="
sbt "runMain fpga.${TOP}App"

echo "=== Step 2: Open-Source Yosys Synthesis (NextPNR flow) ==="
yosys -p "synth_xilinx -flatten -top $TOP; write_json $TOP.json" *.v

echo "=== Step 3: Fast NextPNR Placement & Routing (Heap Placer) ==="
nextpnr-xilinx --chipdb /opt/conda/envs/xc7/share/nextpnr-xilinx/xc7a100tcsg324-1.bin --json "$TOP.json" --fasm "$TOP.fasm" --xdc "$XDC" --placer heap --freq 4 --timing-allow-fail

echo "=== Step 4: Bitstream Assembly ==="
python3 scripts/assemble_fasm.py "$TOP" "xc7a100tcsg324-1"
xc7frames2bit --part_file /opt/conda/envs/xc7/share/symbiflow/prjxray-db/artix7/xc7a100tcsg324-1/part.yaml --part_name xc7a100tcsg324-1 --frm_file "$TOP.frames" --output_file "$TOP.bit"

cp -f "$TOP.bit" HelloWorld.bit

echo "=== Container Build Complete: $TOP.bit Generated! ==="