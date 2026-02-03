# ZMK Firmware Local Build Configuration
# Adjust these paths to match your local setup
ZMK_ROOT ?= $(HOME)/path/to/zmk
VENV ?= $(ZMK_ROOT)/.venv
CONFIG_PATH := $(CURDIR)/config

# Build directories
BUILD_BASE := $(ZMK_ROOT)/app/build
BUILD_HSV_LEFT := $(BUILD_BASE)/hsv/left
BUILD_HSV_RIGHT := $(BUILD_BASE)/hsv/right

# Board and shield configuration
BOARD_NICENANO := nice_nano
SHIELD_LEFT := hillside_view_left nice_view
SHIELD_RIGHT := hillside_view_right
SNIPPET_STUDIO := studio-rpc-usb-uart

# Upload configuration
MOUNT_POINT ?= /run/media/$(USER)/NICENANO
UPLOAD_TIMEOUT ?= 60

.PHONY: all left right clean update upload-left upload-right help

all: left right

# Build left side (central) with ZMK Studio support
left:
	@echo "Building Hillside View - Left (Central)"
	cd $(ZMK_ROOT)/app && \
	. $(VENV)/bin/activate && \
	west build -p -d $(BUILD_HSV_LEFT) -b $(BOARD_NICENANO) \
		-- -DSHIELD="$(SHIELD_LEFT)" -DZMK_CONFIG=$(CONFIG_PATH)

# Build right side (peripheral)
right:
	@echo "Building Hillside View - Right (Peripheral)"
	cd $(ZMK_ROOT)/app && \
	. $(VENV)/bin/activate && \
	west build -p -d $(BUILD_HSV_RIGHT) -b $(BOARD_NICENANO) \
		-- -DSHIELD="$(SHIELD_RIGHT)" -DZMK_CONFIG=$(CONFIG_PATH)

# Update west dependencies (run after modifying west.yml)
update:
	@echo "Updating west dependencies"
	cd $(ZMK_ROOT)/app && \
	. $(VENV)/bin/activate && \
	west update

# Clean build directories
clean:
	@echo "Cleaning build directories"
	rm -rf $(BUILD_HSV_LEFT) $(BUILD_HSV_RIGHT)

# Upload left side firmware to board
upload-left:
	@echo "Waiting for bootloader device (NICENANO)..."
	@echo "Please connect the left side in bootloader mode"
	@timeout=$(UPLOAD_TIMEOUT); \
	elapsed=0; \
	device=""; \
	while [ -z "$$device" ] && [ $$elapsed -lt $$timeout ]; do \
		device=$$(lsblk -no NAME,LABEL 2>/dev/null | grep NICENANO | awk '{print "/dev/"$$1}'); \
		if [ -z "$$device" ]; then \
			sleep 1; \
			elapsed=$$((elapsed + 1)); \
		fi; \
	done; \
	if [ -z "$$device" ]; then \
		echo "Error: Bootloader device not found after $(UPLOAD_TIMEOUT)s"; \
		exit 1; \
	fi; \
	echo "✓ Device detected: $$device"; \
	echo "Mounting device..."; \
	mount_point=$$(udisksctl mount -b $$device 2>&1 | grep -oP 'Mounted .* at \K.*' || echo ""); \
	if [ -z "$$mount_point" ]; then \
		mount_point=$$(lsblk -no MOUNTPOINT $$device 2>/dev/null | head -1); \
	fi; \
	if [ -z "$$mount_point" ] || [ ! -d "$$mount_point" ]; then \
		echo "Error: Failed to mount device"; \
		exit 1; \
	fi; \
	echo "✓ Mounted at: $$mount_point"; \
	echo "Uploading firmware..."; \
	until cp $(BUILD_HSV_LEFT)/zephyr/zmk.uf2 $$mount_point/; do \
		echo "Upload failed, retrying..."; \
		sleep 1; \
	done; \
	sync; \
	echo "✓ Left side firmware uploaded successfully"; \
	echo "Board will reboot automatically"

# Upload right side firmware to board
upload-right:
	@echo "Waiting for bootloader device (NICENANO)..."
	@echo "Please connect the right side in bootloader mode"
	@timeout=$(UPLOAD_TIMEOUT); \
	elapsed=0; \
	device=""; \
	while [ -z "$$device" ] && [ $$elapsed -lt $$timeout ]; do \
		device=$$(lsblk -no NAME,LABEL 2>/dev/null | grep NICENANO | awk '{print "/dev/"$$1}'); \
		if [ -z "$$device" ]; then \
			sleep 1; \
			elapsed=$$((elapsed + 1)); \
		fi; \
	done; \
	if [ -z "$$device" ]; then \
		echo "Error: Bootloader device not found after $(UPLOAD_TIMEOUT)s"; \
		exit 1; \
	fi; \
	echo "✓ Device detected: $$device"; \
	echo "Mounting device..."; \
	mount_point=$$(udisksctl mount -b $$device 2>&1 | grep -oP 'Mounted .* at \K.*' || echo ""); \
	if [ -z "$$mount_point" ]; then \
		mount_point=$$(lsblk -no MOUNTPOINT $$device 2>/dev/null | head -1); \
	fi; \
	if [ -z "$$mount_point" ] || [ ! -d "$$mount_point" ]; then \
		echo "Error: Failed to mount device"; \
		exit 1; \
	fi; \
	echo "✓ Mounted at: $$mount_point"; \
	echo "Uploading firmware..."; \
	until cp $(BUILD_HSV_RIGHT)/zephyr/zmk.uf2 $$mount_point/; do \
		echo "Upload failed, retrying..."; \
		sleep 1; \
	done; \
	sync; \
	echo "✓ Right side firmware uploaded successfully"; \
	echo "Board will reboot automatically"

# Display help information
help:
	@echo "ZMK Firmware Build System"
	@echo ""
	@echo "Usage:"
	@echo "  make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  all          - Build both left and right firmware (default)"
	@echo "  left         - Build left side (central) with ZMK Studio"
	@echo "  right        - Build right side (peripheral)"
	@echo "  upload-left  - Upload left side firmware to board"
	@echo "  upload-right - Upload right side firmware to board"
	@echo "  update       - Update west dependencies"
	@echo "  clean        - Remove build artifacts"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Configuration:"
	@echo "  ZMK_ROOT     - ZMK installation path (default: $(ZMK_ROOT))"
	@echo "  MOUNT_POINT  - Board mount point (default: $(MOUNT_POINT))"
	@echo "  UPLOAD_TIMEOUT - Upload wait timeout in seconds (default: $(UPLOAD_TIMEOUT))"
	@echo ""
	@echo "Examples:"
	@echo "  make ZMK_ROOT=~/zmk left"
	@echo "  make upload-left MOUNT_POINT=/media/NICENANO"
	@echo ""
	@echo "Firmware output:"
	@echo "  Left:  $(BUILD_HSV_LEFT)/zephyr/zmk.uf2"
	@echo "  Right: $(BUILD_HSV_RIGHT)/zephyr/zmk.uf2"
