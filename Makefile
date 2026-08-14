BOARD ?= nexys_a7_100
BITSTREAM ?= fpga/TopAudioAccelerator.bit
ESP_IP ?= 192.168.5.72
JAG ?= $(shell which jag 2>/dev/null || echo $(HOME)/.local/bin/jag)
PYTHON ?= python3

.PHONY: help flash flash-fpga flash-esp esp client build clean

help:
	@echo "FPGA Accelerated Audio Player - Setup & Commands"
	@echo "================================================"
	@echo "make flash         - Flash latest FPGA bitstream to $(BOARD)"
	@echo "make esp           - Deploy & run audio streamer on ESP32 ($(ESP_IP))"
	@echo "make client        - Launch real-time desktop audio streaming client"
	@echo "make build-fpga    - Rebuild FPGA bitstream from Chisel HDL in container"
	@echo "make clean         - Clean temporary build artifacts"

flash: flash-fpga

flash-fpga:
	@echo "Flashing $(BITSTREAM) to $(BOARD)..."
	openFPGALoader -b $(BOARD) $(BITSTREAM)

flash-esp: esp

esp:
	@echo "Deploying audio_streamer.toit to ESP32 ($(ESP_IP))..."
	$(JAG) run -d $(ESP_IP) esp/audio_streamer.toit

client:
	@echo "Starting audio client pointing to $(ESP_IP)..."
	$(PYTHON) client/audio_client.py --target $(ESP_IP)

build: build-fpga

build-fpga:
	@echo "Recompiling FPGA bitstream..."
	$(MAKE) -C fpga build

clean:
	$(MAKE) -C fpga clean
