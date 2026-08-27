BOARD ?= nexys_a7_100
BITSTREAM ?= fpga/TopAudioAccelerator.bit
ESP_DEVICE ?= nervous-bother
ESP_IP ?= 192.168.5.73
ESP_USB ?= /dev/ttyUSB2
JAG ?= $(shell which jag 2>/dev/null || echo $(HOME)/.local/bin/jag)
PYTHON ?= python3

ifeq (fpga,$(firstword $(MAKECMDGOALS)))
  FPGA_CMD := $(word 2,$(MAKECMDGOALS))
  $(eval $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS)):;@:)
endif

ifeq (client,$(firstword $(MAKECMDGOALS)))
  CLIENT_CMD := $(word 2,$(MAKECMDGOALS))
  $(eval $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS)):;@:)
endif

.PHONY: all help fpga esp client clean

all:
	@$(MAKE) -j2 esp fpga
	@$(MAKE) client

help:
	@echo "FPGA Accelerated Audio Player"
	@echo "============================="
	@echo "make             - Deploy ESP, build & flash FPGA in parallel, then start client"
	@echo "make fpga        - Build & flash FPGA bitstream to $(BOARD)"
	@echo "make fpga build  - Build FPGA bitstream only"
	@echo "make fpga flash  - Flash FPGA bitstream to $(BOARD) only"
	@echo "make esp         - Deploy & run audio streamer on ESP32 ($(ESP_DEVICE))"
	@echo "make client      - Launch audio streaming client ($(ESP_IP))"
	@echo "make client usb  - Launch audio streaming client via USB (/dev/ttyUSB0)"
	@echo "make clean       - Clean build artifacts"

fpga:
ifeq ($(FPGA_CMD),flash)
	@echo "Flashing $(BITSTREAM) to $(BOARD)..."
	openFPGALoader -b $(BOARD) $(BITSTREAM)
else ifeq ($(FPGA_CMD),build)
	@echo "Recompiling FPGA bitstream..."
	$(MAKE) -C fpga build
else ifeq ($(FPGA_CMD),)
	@echo "Building FPGA bitstream..."
	$(MAKE) -C fpga build
	@echo "Flashing $(BITSTREAM) to $(BOARD)..."
	openFPGALoader -b $(BOARD) $(BITSTREAM)
else
	@echo "Unknown FPGA command '$(FPGA_CMD)'. Use 'make fpga', 'make fpga build', or 'make fpga flash'."
	@exit 1
endif

esp:
	@echo "Deploying audio_streamer.toit to ESP32 ($(ESP_DEVICE))..."
	$(JAG) run -d $(ESP_DEVICE) esp/audio_streamer.toit

client:
ifeq ($(CLIENT_CMD),usb)
	@echo "Starting audio client pointing to USB ($(ESP_USB))..."
	$(PYTHON) client/audio_client.py --usb $(ESP_USB)
else ifeq ($(CLIENT_CMD),)
	@echo "Starting audio client pointing to $(ESP_IP)..."
	$(PYTHON) client/audio_client.py --target $(ESP_IP)
else
	@echo "Unknown client command '$(CLIENT_CMD)'. Use 'make client' or 'make client usb'."
	@exit 1
endif

clean:
	$(MAKE) -C fpga clean
