#!/usr/bin/env python3
"""
Ultra Low-Latency M-Audio M-Track Solo Guitar Streamer
Streams guitar line directly from M-Audio M-Track Solo to FPGA Audio Accelerator.
"""

import argparse
import glob
import math
import os
import socket
import sys
import time
import numpy as np

try:
    import sounddevice as sd
except ImportError:
    sys.exit("Error: 'sounddevice' library is required. Install with: pip install sounddevice")

try:
    import serial
except ImportError:
    serial = None

ESP_IP = "192.168.5.73"
ESP_PORT = 4440
SAMPLE_RATE = 48000
FRAME_SAMPLES = 480  # 10 ms per packet (480 / 48000 = 0.010 s)
FRAME_BYTES = FRAME_SAMPLES * 2  # 960 bytes (Mono 16-bit PCM)
SYNC_WORD = b'\x5a\xa5\x5a\xa5'


def find_mtrack_device():
    """Find the M-Audio M-Track Solo input device."""
    devices = sd.query_devices()
    preferred_idx = None

    for idx, dev in enumerate(devices):
        if dev['max_input_channels'] >= 1:
            name = dev['name']
            # Direct ALSA hardware device preferred for lowest latency
            if ('USB AUDIO' in name or 'PCM2900' in name or 'CODEC' in name):
                if 'hw:' in name:
                    return idx, name
                if preferred_idx is None:
                    preferred_idx = (idx, name)

    return preferred_idx if preferred_idx else (None, None)


def find_esp_serial_port():
    """Detect ESP32 USB serial port (/dev/ttyUSB2 or CH340)."""
    by_id = glob.glob("/dev/serial/by-id/*")
    for p in by_id:
        target = os.path.realpath(p)
        if "1a86" in p.lower() or "ch340" in p.lower() or "cp210" in p.lower() or "usb_serial" in p.lower():
            return target

    # Fallback check
    if os.path.exists("/dev/ttyUSB2"):
        return "/dev/ttyUSB2"
    return "/dev/ttyUSB0"


def parse_args():
    parser = argparse.ArgumentParser(
        description="Stream M-Audio M-Track Solo guitar line to FPGA audio accelerator with minimal delay."
    )
    parser.add_argument("--target", default=ESP_IP, help=f"Target ESP32 IP address (default: {ESP_IP})")
    parser.add_argument("--port", type=int, default=ESP_PORT, help=f"Target ESP32 UDP port (default: {ESP_PORT})")
    parser.add_argument(
        "--channel",
        choices=["1", "2", "mix", "auto"],
        default="2",
        help="Input channel to capture: 1=Mic/Line1, 2=Guitar/Inst2 (default: 2), mix=Average both, auto=Highest signal",
    )
    parser.add_argument(
        "--usb",
        nargs="?",
        const="auto",
        default=None,
        help="Send audio over USB serial instead of UDP for lowest latency (e.g. /dev/ttyUSB2 or 'auto')",
    )
    parser.add_argument("--baud", type=int, default=2000000, help="Baud rate for serial connection (default: 2000000)")
    parser.add_argument("--device", type=int, default=None, help="Explicit sounddevice input device index")
    parser.add_argument("--gain", type=float, default=1.0, help="Software digital gain multiplier (default: 1.0)")
    return parser.parse_args()


class GuitarStreamer:
    def __init__(self, args):
        self.args = args
        self.device_idx = args.device
        self.device_name = None

        if self.device_idx is None:
            self.device_idx, self.device_name = find_mtrack_device()
            if self.device_idx is None:
                sys.exit("Error: Could not find M-Audio M-Track Solo (USB AUDIO CODEC). Specify --device manually.")
        else:
            self.device_name = sd.query_devices(self.device_idx)['name']

        # Determine transport
        self.serial_conn = None
        self.sock = None
        if args.usb is not None:
            if serial is None:
                sys.exit("Error: 'pyserial' library required for USB streaming. Install with: pip install pyserial")
            port = find_esp_serial_port() if args.usb == "auto" else args.usb
            print(f"[Transport] Connecting to ESP32 USB serial: {port} @ {args.baud} baud...")
            self.serial_conn = serial.Serial(port, args.baud, timeout=0.1)
        else:
            print(f"[Transport] UDP Wi-Fi Stream -> {args.target}:{args.port}")
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

        self.tx_count = 0
        self.last_meter_time = time.time()
        self.latest_rms_db = -99.0
        self.latest_peak = 0.0

    def audio_callback(self, indata, frames, time_info, status):
        if status:
            pass  # Input overflow/underflow warnings ignored for minimal latency

        # indata shape is (frames, 2), dtype=int16
        ch_arg = self.args.channel
        if ch_arg == "2":
            mono = indata[:, 1]  # Channel 2: Guitar / Instrument
        elif ch_arg == "1":
            mono = indata[:, 0]  # Channel 1: Mic / Line
        elif ch_arg == "mix":
            mono = ((indata[:, 0].astype(np.int32) + indata[:, 1].astype(np.int32)) // 2).astype(np.int16)
        elif ch_arg == "auto":
            rms0 = np.mean(indata[:, 0].astype(np.float32) ** 2)
            rms1 = np.mean(indata[:, 1].astype(np.float32) ** 2)
            mono = indata[:, 1] if rms1 >= rms0 else indata[:, 0]
        else:
            mono = indata[:, 1]

        # Apply digital gain if requested
        if self.args.gain != 1.0:
            boosted = np.clip(mono.astype(np.float32) * self.args.gain, -32768.0, 32767.0).astype(np.int16)
            raw_bytes = boosted.tobytes()
        else:
            raw_bytes = mono.tobytes()

        # Send immediately
        try:
            if self.serial_conn:
                self.serial_conn.write(SYNC_WORD + raw_bytes)
            else:
                self.sock.sendto(raw_bytes, (self.args.target, self.args.port))
            self.tx_count += 1
        except Exception:
            pass

        # Compute level stats for live meter
        arr_f = mono.astype(np.float32) / 32768.0
        peak = float(np.max(np.abs(arr_f)))
        rms = float(np.sqrt(np.mean(arr_f ** 2)))
        rms_db = 20.0 * math.log10(rms) if rms > 1e-5 else -99.0

        self.latest_rms_db = rms_db
        self.latest_peak = peak

    def run(self):
        print(f"\n=======================================================")
        print(f"  M-Track Solo -> FPGA Audio Accelerator Streamer")
        print(f"=======================================================")
        print(f"Device:    [{self.device_idx}] {self.device_name}")
        print(f"Track:     Input {self.args.channel} ({'Guitar/Line 2' if self.args.channel == '2' else self.args.channel})")
        print(f"Format:    16-bit Mono @ {SAMPLE_RATE} Hz ({FRAME_SAMPLES} samples/packet = 10 ms)")
        print(f"Gain:      {self.args.gain}x")
        if self.serial_conn:
            print(f"Transport: USB Serial (Minimal delay, zero-jitter)")
        else:
            print(f"Transport: UDP Wi-Fi ({self.args.target}:{self.args.port})")
        print(f"=======================================================\n")
        print("Streaming live guitar... Press Ctrl+C to stop.\n")

        # Open low-latency input stream with callback
        with sd.InputStream(
            device=self.device_idx,
            channels=2,
            samplerate=SAMPLE_RATE,
            blocksize=FRAME_SAMPLES,
            dtype="int16",
            latency="low",
            callback=self.audio_callback,
        ):
            while True:
                time.sleep(0.05)
                now = time.time()
                if now - self.last_meter_time >= 0.1:
                    self.last_meter_time = now
                    # Render live VU meter
                    bars_len = 30
                    filled = int(min(max(self.latest_peak, 0.0), 1.0) * bars_len)
                    meter = "#" * filled + "-" * (bars_len - filled)
                    level_str = f"{self.latest_rms_db:5.1f} dB" if self.latest_rms_db > -90 else "  SILENT"
                    sys.stdout.write(
                        f"\r[GUITAR] [{meter}] {level_str} | Peak: {self.latest_peak*100:4.1f}% | Packets: {self.tx_count:6d}"
                    )
                    sys.stdout.flush()

    def close(self):
        if self.serial_conn:
            try:
                self.serial_conn.close()
            except Exception:
                pass
        if self.sock:
            try:
                self.sock.close()
            except Exception:
                pass
        print("\nStream stopped.")


def main():
    args = parse_args()
    streamer = GuitarStreamer(args)
    try:
        streamer.run()
    except KeyboardInterrupt:
        pass
    finally:
        streamer.close()


if __name__ == "__main__":
    main()
