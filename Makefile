BOARD ?= nexys_a7_100
BITSTREAM ?= fpga/TopAudioAccelerator.bit
ESP_DEVICE ?= forbidden-fruit
ESP_IP ?= 192.168.5.73
JAG ?= $(shell which jag 2>/dev/null || echo $(HOME)/.local/bin/jag)
PYTHON ?= python3

.PHONY: help flash flash-fpga flash-esp esp client build clean

help:
	@echo "FPGA Accelerated Audio Player - Setup & Commands"
	@echo "================================================"
	@echo "make flash         - Flash latest FPGA bitstream to $(BOARD)"
	@echo "make esp           - Deploy & run audio streamer on ESP32 ($(ESP_DEVICE))"
	@echo "make client        - Launch real-time desktop audio streaming client ($(ESP_IP))"
	@echo "make build-fpga    - Rebuild FPGA bitstream from Chisel HDL in container"
	@echo "make clean         - Clean temporary build artifacts"

flash: flash-fpga

flash-fpga:
	@echo "Flashing $(BITSTREAM) to $(BOARD)..."
	openFPGALoader -b $(BOARD) $(BITSTREAM)

flash-esp: esp

esp:
	@echo "Deploying audio_streamer.toit to ESP32 ($(ESP_DEVICE))..."
	$(JAG) run -d $(ESP_DEVICE) esp/audio_streamer.toit

client:
	@echo "Starting audio client pointing to $(ESP_IP)..."
	$(PYTHON) client/audio_client.py --target $(ESP_IP)

build: build-fpga

build-fpga:
	@echo "Recompiling FPGA bitstream..."
	$(MAKE) -C fpga build

clean:
	$(MAKE) -C fpga clean

.PHONY: wiring-test wiring-drive

PC_IP ?= $(shell ip -4 addr | awk '/inet 192\.168\.5\./{print $$2; exit}' | cut -d/ -f1)

wiring-drive:
	@echo "Building + flashing FPGA JA drive test (8 freq fingerprints + heartbeat)..."
	$(MAKE) -C fpga build TOP=JaDriveTop XDC=constraints/ja_drive.xdc
	$(MAKE) -C fpga flash TOP=JaDriveTop
	@echo "Watch telemetry for 'ALIVE': stty -F /dev/ttyUSB2 115200 raw -echo && cat /dev/ttyUSB2"

wiring-test:
	@echo "Wiring test: FPGA drives 8 freqs on JA, ESP reads all its GPIOs."
	@test -n "$(PC_IP)" || (echo "ERROR: no 192.168.5.x address on this PC"; exit 1)
	@mkdir -p /tmp/kilo
	@sed "s/192\.168\.5\.100/$(PC_IP)/" scripts/wiring/gpio_read.toit > /tmp/kilo/gpio_read.gen.toit
	@python3 scripts/wiring/listen.py 9998 30 > /tmp/kilo/wiring.out & \
	trap 'kill %1 2>/dev/null' EXIT; \
	sleep 1; \
	$(JAG) run -d $(ESP_DEVICE) /tmp/kilo/gpio_read.gen.toit; \
	sleep 12; \
	cat /tmp/kilo/wiring.out
