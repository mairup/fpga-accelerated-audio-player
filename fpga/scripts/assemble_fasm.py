import os
import sys
from prjxray.db import Database
from prjxray.fasm_assembler import FasmAssembler

def main():
    db_root = "/opt/conda/envs/xc7/share/symbiflow/prjxray-db/artix7"
    if not os.path.exists(db_root):
        db_root = "/home/mai/miniconda3/envs/xc7/share/symbiflow/prjxray-db/artix7"

    stem = sys.argv[1] if len(sys.argv) > 1 else "TopAudioAccelerator"
    part_name = sys.argv[2] if len(sys.argv) > 2 else "xc7a100tcsg324-1"

    fasm_file = f"{stem}.fasm"
    frames_file = f"{stem}.frames"

    db = Database(db_root, part_name)
    assembler = FasmAssembler(db)
    assembler.parse_fasm_filename(fasm_file)
    frames = assembler.get_frames(sparse=True)

    with open(frames_file, "w") as out:
        for addr in sorted(frames.keys()):
            words_str = ",".join(f"0x{w:08x}" for w in frames[addr])
            out.write(f"0x{addr:08x} {words_str}\n")

    print(f"Successfully generated {frames_file} for {part_name}")

if __name__ == "__main__":
    main()
