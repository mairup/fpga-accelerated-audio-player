import socket
import sys
import time

PORT = 9998
WINDOW = float(sys.argv[1]) if len(sys.argv) > 1 else 25.0

EXPECTED = [
    ("JA1", "C17", 200),
    ("JA2", "D17", 133),
    ("JA3", "E17", 80),
    ("JA4", "F18", 57),
    ("JA5", "G18", 36),
    ("JA6", "H18", 27),
    ("JA7", "J18", 19),
    ("JA8", "K18", 15),
]


def decode(edge_map):
    if not edge_map.strip():
        print("\nRESULT: no ESP GPIO saw any FPGA output -- harness path is broken.")
        print("        Check: ribbon fully seated, correct Pmod (JA), wire alignment.")
        return
    print("\nRESULT: coupling detected! ESP GPIO -> FPGA pin map:")
    for entry in edge_map.split(","):
        gpio, _, count = entry.partition(":")
        try:
            count = int(count)
        except ValueError:
            continue
        ja, loc, exp = min(EXPECTED, key=lambda e: abs(e[2] - count))
        confidence = "OK" if abs(count - exp) <= max(3, exp // 5) else "UNSURE"
        print(f"  ESP GPIO {gpio:>2}: {count:4d} edges  =>  {ja} ({loc}, expects ~{exp})  [{confidence}]")


sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind(("0.0.0.0", PORT))
sock.settimeout(WINDOW)
deadline = time.time() + WINDOW
while time.time() < deadline:
    try:
        data, addr = sock.recvfrom(2048)
    except socket.timeout:
        break
    text = data.decode(errors="replace")
    if text.startswith("LEVELS:"):
        entries = text[len("LEVELS:"):].split(",")
        levels = [e.split("=", 1)[1] if "=" in e else "?" for e in entries]
        print("LEVELS (first->last):")
        for e in entries:
            print(f"  {e}")
        ones = sum(1 for l in levels if l.endswith("1"))
        zeros = sum(1 for l in levels if l.endswith("0"))
        moved = sum(1 for l in levels if "->" in l and l[0] != l.split("->")[1])
        print(f"  summary: {zeros} pins low, {ones} pins high, {moved} changed level during capture")
        continue
    if text.startswith("EDGE-MAP:"):
        decode(text[len("EDGE-MAP:"):])
        sys.exit(0)
    print(f"{addr[0]}: {text}")
print("\nNo EDGE-MAP received (ESP reader did not finish).")
sys.exit(1)
