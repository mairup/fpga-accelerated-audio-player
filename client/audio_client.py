#!/usr/bin/env python3

import argparse
import math
import os
import socket
import serial
import struct
import subprocess
import sys
import time
import numpy as np

ESP_PORT = 4440
SAMPLE_RATE = 48000
CHANNELS = 1
FRAME_SAMPLES = 480  # 10 ms per packet (480 / 48000 = 0.010 s)
FRAME_BYTES = FRAME_SAMPLES * CHANNELS * 2  # 960 bytes audio payload (Mono 16-bit PCM)
SYNC_WORD = b'\x5a\xa5\x5a\xa5'

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Audio Streamer Client")
    parser.add_argument("--target", default="192.168.5.73", help="Target ESP32 IP address")
    parser.add_argument("--port", type=int, default=ESP_PORT, help="Target ESP32 UDP port")
    parser.add_argument("--synth", action="store_true", help="Generate continuous 440 Hz test tone mode")
    parser.add_argument("--burst", action="store_true", help="Generate 2 Hz ON/OFF burst test pattern mode")
    parser.add_argument("--static-test", action="store_true", help="Tell ESP32 to send a static bit-pattern over I2S")
    parser.add_argument("--restore", action="store_true", help="Restore physical system audio output")
    parser.add_argument("--usb", type=str, help="Send audio over serial port instead of UDP (e.g. /dev/ttyUSB0)")
    parser.add_argument("--baud", type=int, default=2000000, help="Baud rate for serial connection")
    return parser.parse_args()

def compute_bytes_rms(raw_bytes: bytes) -> float:
    if not raw_bytes or len(raw_bytes) < 2:
        return -99.0
    arr = np.frombuffer(raw_bytes, dtype=np.int16).astype(np.float64) / 32767.0
    rms = np.sqrt(np.mean(arr ** 2))
    if rms <= 1e-5:
        return -99.0
    return 20.0 * math.log10(rms)

def list_physical_sinks():
    sinks = []
    try:
        res = subprocess.check_output(["pactl", "list", "short", "sinks"], text=True)
        for line in res.splitlines():
            parts = line.split()
            if len(parts) >= 2:
                name = parts[1]
                if "fpga_audio_relay" not in name and "null" not in name:
                    sinks.append(name)
    except Exception:
        pass
    return sinks

def select_physical_sink(user_choice=None):
    sinks = list_physical_sinks()
    if not sinks:
        return "alsa_output.pci-0000_10_00.6.analog-stereo"
    if user_choice is not None:
        try:
            idx = int(user_choice)
            if 0 <= idx < len(sinks):
                return sinks[idx]
        except ValueError:
            for s in sinks:
                if user_choice.lower() in s.lower():
                    return s
    return sinks[0]

def create_virtual_sink(name_label):
    sink_name = "fpga_audio_relay"
    try:
        cmd = ["pactl", "load-module", "module-null-sink", f"sink_name={sink_name}", f"sink_properties=device.description={name_label}"]
        res = subprocess.check_output(cmd, text=True).strip()
        return res, sink_name
    except Exception:
        return None, None

def set_default_sink(sink_name):
    try:
        subprocess.run(["pactl", "set-default-sink", sink_name], check=False)
    except Exception:
        pass

def restore_default_sink(sink_name):
    try:
        subprocess.run(["pactl", "set-default-sink", sink_name], check=False)
        print(f"Restored Default System Output to [{sink_name}]")
    except Exception:
        pass

def cleanup_all_virtual_sinks():
    try:
        res = subprocess.check_output(["pactl", "list", "short", "modules"], text=True)
        for line in res.splitlines():
            if "fpga_audio_relay" in line or "FPGA_Audio_Accelerator" in line:
                parts = line.split()
                if len(parts) >= 1:
                    mod_id = parts[0]
                    subprocess.run(["pactl", "unload-module", str(mod_id)], check=False)
    except Exception:
        pass

class AudioStreamerClient:
    def __init__(self, target_host: str, target_port: int, synth: bool = False, burst: bool = False, static_test: bool = False, usb_port: str = None, baud: int = 2000000) -> None:
        self.target_host = target_host
        self.target_port = target_port
        self.synth = synth
        self.burst = burst
        self.static_test = static_test
        self.usb_port = usb_port
        self.baud = baud
        if self.usb_port:
            self.serial = serial.Serial(self.usb_port, self.baud, timeout=1)
            self.serial.dtr = False
            self.serial.rts = False
        else:
            self.serial = None
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.running = False
        self.seq = 0
        self.rec_proc = None
        self.physical_sink = None
        self.tx_count = 0
        self.cap_rms_db = -99.0

    def start(self) -> None:
        self.running = True
        if self.serial:
            print(f"Audio Streamer -> Target USB: {self.usb_port} @ {self.baud} baud")
        else:
            print(f"Audio Streamer -> Target ESP32: {self.target_host}:{self.target_port}")
        if self.static_test:
            self.static_test_loop()
        elif self.burst:
            self.burst_loop()
        elif self.synth:
            self.synth_loop()
        else:
            self.stream_loop()

    def stop(self) -> None:
        self.running = False
        if self.rec_proc:
            try:
                self.rec_proc.terminate()
            except Exception:
                pass
        if self.physical_sink:
            restore_default_sink(self.physical_sink)
        cleanup_all_virtual_sinks()
        if self.serial:
            self.serial.close()

    def static_test_loop(self) -> None:
        print("Sending 0x8765 and 0x1234 test pattern to ESP32...")
        pattern = bytes([0x65, 0x87, 0x34, 0x12])
        num_tiles = FRAME_BYTES // 4
        payload = pattern * num_tiles
        
        while self.running:
            try:
                if self.serial:
                    self.serial.write(SYNC_WORD + payload)
                    self.serial.flush()
                else:
                    self.sock.sendto(payload, (self.target_host, self.target_port))
                self.tx_count += 1
                self.seq = (self.seq + 1) & 0xFFFFFFFF
            except OSError:
                pass
            if self.tx_count % 10 == 0:
                print(f"[STATIC TEST] Sent {self.tx_count} pattern packets to ESP32...")
            time.sleep(0.010)

    def burst_loop(self) -> None:
        print("Generating 2 Hz ON/OFF Burst Test Pattern (Mono 16-bit @ 100 pkts/s)...")
        t_step = 1.0 / SAMPLE_RATE
        last_meter = 0
        frame_interval = FRAME_SAMPLES / float(SAMPLE_RATE)
        next_time = time.time()
        while self.running:
            burst_cycle = (self.seq * FRAME_SAMPLES / SAMPLE_RATE) % 0.5
            is_on = burst_cycle < 0.25
            if is_on:
                t = np.arange(FRAME_SAMPLES) * t_step + (self.seq * FRAME_SAMPLES * t_step)
                sine_wave = (0.61 * np.sin(2.0 * np.pi * 440.0 * t) * 32767.0).astype(np.int16)
            else:
                sine_wave = np.zeros(FRAME_SAMPLES, dtype=np.int16)

            raw_in = sine_wave.tobytes()
            self.cap_rms_db = compute_bytes_rms(raw_in)
            self.seq = (self.seq + 1) & 0xFFFFFFFF
            try:
                if self.serial:
                    self.serial.write(SYNC_WORD + raw_in)
                    self.serial.flush()
                else:
                    self.sock.sendto(raw_in, (self.target_host, self.target_port))
                self.tx_count += 1
            except OSError:
                pass

            now = time.time()
            if now - last_meter >= 0.25:
                last_meter = now
                state_str = "BURST ON " if is_on else "BURST OFF"
                sys.stdout.write(f"\r[BURST] State: {state_str} | RMS: {self.cap_rms_db:5.1f} dB | Sent: {self.tx_count:6d} pkts")
                sys.stdout.flush()
            next_time += frame_interval
            sleep_time = next_time - time.time()
            if sleep_time > 0:
                time.sleep(sleep_time)

    def synth_loop(self) -> None:
        print("Synthesizing 440 Hz tone (Mono 16-bit @ 100 pkts/s)...")
        t_step = 1.0 / SAMPLE_RATE
        last_meter = 0
        frame_interval = FRAME_SAMPLES / float(SAMPLE_RATE)
        next_time = time.time()
        while self.running:
            t = np.arange(FRAME_SAMPLES) * t_step + (self.seq * FRAME_SAMPLES * t_step)
            sine_wave = (0.5 * np.sin(2.0 * np.pi * 440.0 * t) * 32767.0).astype(np.int16)
            raw_in = sine_wave.tobytes()
            self.cap_rms_db = compute_bytes_rms(raw_in)
            self.seq = (self.seq + 1) & 0xFFFFFFFF
            try:
                if self.serial:
                    self.serial.write(SYNC_WORD + raw_in)
                    self.serial.flush()
                else:
                    self.sock.sendto(raw_in, (self.target_host, self.target_port))
                self.tx_count += 1
            except OSError:
                pass
            now = time.time()
            if now - last_meter >= 0.25:
                last_meter = now
                cap_str = f"{self.cap_rms_db:5.1f} dB" if self.cap_rms_db > -90 else "   SILENT"
                sys.stdout.write(f"\r[SYNTH] Output: {cap_str} | Sent: {self.tx_count:6d} pkts")
                sys.stdout.flush()
            next_time += frame_interval
            sleep_time = next_time - time.time()
            if sleep_time > 0:
                time.sleep(sleep_time)

    def stream_loop(self) -> None:
        cleanup_all_virtual_sinks()
        self.physical_sink = select_physical_sink(0)
        _, sink_name = create_virtual_sink("FPGA_Audio_Accelerator")
        if sink_name:
            set_default_sink(sink_name)
            print(f"Virtual sink [FPGA_Audio_Accelerator] set as default output.")
        monitor_source = f"{sink_name}.monitor" if sink_name else f"{self.physical_sink}.monitor"
        rec_cmd = ["parec", "--format=s16le", "--channels=1", f"--rate={SAMPLE_RATE}", "--latency-msec=10", f"--device={monitor_source}"]
        try:
            self.rec_proc = subprocess.Popen(rec_cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        except Exception as e:
            print(f"Error starting capture: {e}")
            return
        print("\nStreaming computer audio (Mono 16-bit @ 100 pkts/s) -> ESP32 -> Nexys A7 FPGA AUX DAC...\n")
        last_meter = 0
        frame_interval = FRAME_SAMPLES / float(SAMPLE_RATE)
        next_time = time.time()
        while self.running:
            try:
                raw_in = self.rec_proc.stdout.read(FRAME_BYTES)
                if len(raw_in) == FRAME_BYTES:
                    now = time.time()
                    if next_time < now - 0.05:
                        next_time = now
                    
                    sleep_time = next_time - time.time()
                    if sleep_time > 0:
                        time.sleep(sleep_time)
                    
                    next_time += frame_interval

                    self.cap_rms_db = compute_bytes_rms(raw_in)
                    self.seq = (self.seq + 1) & 0xFFFFFFFF
                    if self.serial:
                        self.serial.write(SYNC_WORD + raw_in)
                        self.serial.flush()
                    else:
                        self.sock.sendto(raw_in, (self.target_host, self.target_port))
                    self.tx_count += 1
                    
                    now_meter = time.time()
                    if now_meter - last_meter >= 0.25:
                        last_meter = now_meter
                        cap_str = f"{self.cap_rms_db:5.1f} dB" if self.cap_rms_db > -90 else "   SILENT"
                        sys.stdout.write(f"\r[STREAMING] Capture: {cap_str} | Sent: {self.tx_count:6d} pkts ({(self.tx_count*10)/1000.0:5.1f}s)")
                        sys.stdout.flush()
                else:
                    time.sleep(0.0005)
            except Exception:
                break

def main() -> None:
    args = parse_args()
    if args.restore:
        restore_default_sink("alsa_output.pci-0000_10_00.6.analog-stereo")
        cleanup_all_virtual_sinks()
        sys.exit(0)

    client = AudioStreamerClient(args.target, args.port, synth=args.synth, burst=args.burst, static_test=args.static_test, usb_port=args.usb, baud=args.baud)
    try:
        client.start()
    except KeyboardInterrupt:
        print("\nStopping Stream...")
    finally:
        client.stop()

if __name__ == "__main__":
    main()
