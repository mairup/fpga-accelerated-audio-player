BOARD ?= nexys_a7_100
BITSTREAM ?= fpga/TopAudioAccelerator.bit
ESP_DEVICE ?= forbidden-fruit
ESP_IP ?= 192.168.5.73
JAG ?= $(shell which jag 2>/dev/null || echo $(HOME)/.local/bin/jag)
PYTHON ?= python3

.PHONY: help flash esp client build clean

help:
	@echo "FPGA Accelerated Audio Player"
	@echo "============================="
	@echo "make flash   - Flash FPGA bitstream to $(BOARD)"
	@echo "make esp     - Deploy & run audio streamer on ESP32 ($(ESP_DEVICE))"
	@echo "make client  - Launch audio streaming client ($(ESP_IP))"
	@echo "make build   - Build FPGA bitstream"
	@echo "make clean   - Clean build artifacts"

flash:
	@echo "Flashing $(BITSTREAM) to $(BOARD)..."
	openFPGALoader -b $(BOARD) $(BITSTREAM)

esp:
	@echo "Deploying audio_streamer.toit to ESP32 ($(ESP_DEVICE))..."
	$(JAG) run -d $(ESP_DEVICE) esp/audio_streamer.toit

client:
	@echo "Starting audio client pointing to $(ESP_IP)..."
	$(PYTHON) client/audio_client.py --target $(ESP_IP)

build:
	@echo "Recompiling FPGA bitstream..."
	$(MAKE) -C fpga build

clean:
	$(MAKE) -C fpga clean
