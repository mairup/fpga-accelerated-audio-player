TOP ?= TopAudioAccelerator
XDC ?= constraints/nexys_a7_100.xdc
PCF ?= constraints/nexys_a7_50t.pcf
BOARD ?= nexys_a7_100

.PHONY: build-images build flash deploy clean

build-images:
	@echo "Building Docker container images..."
	docker build -t fpga-builder -f Dockerfile.builder \
	  --build-arg UID=$$(id -u) --build-arg GID=$$(id -g) .
	docker build -t fpga-flasher -f Dockerfile.flasher .

build:
	@echo "Running containerized compilation for $(TOP)..."
	docker run --rm \
	  -e TOP=$(TOP) -e XDC=$(XDC) -e PCF=$(PCF) \
	  -v "$$(pwd):/workspace" \
	  fpga-builder

flash:
	@echo "Flashing $(TOP).bit to $(BOARD)..."
	openFPGALoader -b $(BOARD) $(TOP).bit

deploy: build flash

clean:
	@echo "Cleaning local build artifacts..."
	rm -f *.anno.json *.fir *.frames *.ioplace *.ilang *.json *.net *.place *.route *.log *.rpt *.fasm *.bit *.v *.eblif *.sdc *.post_routing constraints.place direndaj.wav output_overdrive.wav
