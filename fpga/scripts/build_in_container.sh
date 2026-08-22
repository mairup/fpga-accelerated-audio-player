#!/usr/bin/env bash
set -e

export F4PGA_INSTALL_DIR=/opt/f4pga
export PATH=/opt/conda/envs/xc7/bin:/usr/local/sbt/bin:$PATH

TOP="${TOP:-TopAudioAccelerator}"
XDC="${XDC:-constraints/nexys_a7_100.xdc}"
PCF="${PCF:-constraints/nexys_a7_50t.pcf}"
USE_NEXTPNR="${USE_NEXTPNR:-1}"

echo "=== Step 0: Cleaning Old Build Artifacts ==="
rm -f "$TOP.eblif" "$TOP.net" "$TOP.place" "$TOP.route" "$TOP.fasm" "$TOP.frames" "$TOP.bit" "$TOP.json" constraints.place HelloWorld.v HelloWorld.bit TopAudioAccelerator.v LedMatrixDiagnosticTop.v LedMatrixTestTop.v DualPort*.v

echo "=== Step 1: Scala Chisel Verilog Generation ==="
sbt "runMain fpga.${TOP}App"

if [ "$USE_NEXTPNR" = "1" ] && [ -f "$XDC" ]; then
    echo "=== Step 2: Open-Source Yosys Synthesis (NextPNR flow) ==="
    yosys -p "synth_xilinx -flatten -top $TOP; write_json $TOP.json" *.v

    echo "=== Step 3: Fast NextPNR Placement & Routing (Heap Placer) ==="
    nextpnr-xilinx --chipdb /opt/conda/envs/xc7/share/nextpnr-xilinx/xc7a100tcsg324-1.bin --json "$TOP.json" --fasm "$TOP.fasm" --xdc "$XDC" --placer heap --freq 4 --timing-allow-fail

    echo "=== Step 4: Bitstream Assembly ==="
    python3 scripts/assemble_fasm.py "$TOP" "xc7a100tcsg324-1"
    xc7frames2bit --part_file /opt/conda/envs/xc7/share/symbiflow/prjxray-db/artix7/xc7a100tcsg324-1/part.yaml --part_name xc7a100tcsg324-1 --frm_file "$TOP.frames" --output_file "$TOP.bit"

else
    echo "=== Step 2: Open-Source Yosys Synthesis (Legacy VPR flow) ==="
    symbiflow_synth -t "$TOP" -v "$TOP.v" -d xc7a50t_test -p xc7a50tcsg324-1

    echo "=== Step 3: Legacy VPR Packing ==="
    symbiflow_pack -d xc7a50t_test -e "$TOP.eblif"

    echo "=== Step 4: Legacy VPR Placement ==="
    symbiflow_place --device xc7a50t_test --part xc7a50tcsg324-1 --eblif "$TOP.eblif" --net "$TOP.net" --pcf "$PCF"

    echo "=== Step 5: Legacy VPR Routing ==="
    symbiflow_route --device xc7a50t_test --part xc7a50tcsg324-1 --eblif "$TOP.eblif" --net "$TOP.net"

    echo "=== Step 6: FASM Generation ==="
    symbiflow_write_fasm -d xc7a50t_test -e "$TOP.eblif"

    echo "=== Step 7: Assembling Bitstream ==="
    python3 scripts/assemble_fasm.py "$TOP" "xc7a50tcsg324-1"
    xc7frames2bit --part_file /opt/conda/envs/xc7/share/symbiflow/prjxray-db/artix7/xc7a50tcsg324-1/part.yaml --part_name xc7a50tcsg324-1 --frm_file "$TOP.frames" --output_file "$TOP.bit"
fi

cp -f "$TOP.bit" HelloWorld.bit

echo "=== Container Build Complete: $TOP.bit Generated! ==="