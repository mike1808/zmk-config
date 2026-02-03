# ZMK Firmware Local Build Configuration
ZMK_ROOT ?= $(HOME)/path/to/zmk
VENV ?= $(ZMK_ROOT)/.venv
CONFIG_PATH := $(CURDIR)/config
BUILD_BASE := $(ZMK_ROOT)/app/build
UPLOAD_TIMEOUT ?= 60

# Board definitions
BOARD_NICENANO := nice_nano
BOARD_XIAO := xiao_ble

# =============================================================================
# Build function: $(call build,name,build_dir,board,shield,extra_cmake_args)
# =============================================================================
define build
	@echo "Building $(1)..."
	cd $(ZMK_ROOT)/app && \
	. $(VENV)/bin/activate && \
	west build -p -d $(2) -b $(3) -- -DSHIELD="$(4)" -DZMK_CONFIG=$(CONFIG_PATH) $(5)
endef

# =============================================================================
# Upload function: $(call upload,name,build_dir,device_pattern)
# =============================================================================
define upload
	@echo "Waiting for bootloader device..."
	@echo "Please connect $(1) in bootloader mode"
	@timeout=$(UPLOAD_TIMEOUT); elapsed=0; device=""; \
	while [ -z "$$device" ] && [ $$elapsed -lt $$timeout ]; do \
		device=$$(lsblk -no NAME,LABEL 2>/dev/null | grep -E '$(3)' | awk '{print "/dev/"$$1}'); \
		[ -z "$$device" ] && sleep 1 && elapsed=$$((elapsed + 1)); \
	done; \
	if [ -z "$$device" ]; then echo "Error: Device not found after $(UPLOAD_TIMEOUT)s"; exit 1; fi; \
	echo "✓ Device: $$device"; \
	mount_point=$$(udisksctl mount -b $$device 2>&1 | grep -oP 'at \K.*' || lsblk -no MOUNTPOINT $$device 2>/dev/null | head -1); \
	if [ -z "$$mount_point" ] || [ ! -d "$$mount_point" ]; then echo "Error: Mount failed"; exit 1; fi; \
	echo "✓ Mounted: $$mount_point"; \
	until cp $(2)/zephyr/zmk.uf2 $$mount_point/; do echo "Retrying..."; sleep 1; done; \
	sync; echo "✓ $(1) uploaded successfully"
endef

# =============================================================================
# Hillside View Configuration
# =============================================================================
HSV_LEFT_DIR     := $(BUILD_BASE)/hsv/left
HSV_RIGHT_DIR    := $(BUILD_BASE)/hsv/right
HSV_LEFT_SHIELD  := hillside_view_left nice_view
HSV_RIGHT_SHIELD := hillside_view_right

# =============================================================================
# Cygnus Configuration
# =============================================================================
CYG_LEFT_DIR      := $(BUILD_BASE)/cygnus/left
CYG_RIGHT_DIR     := $(BUILD_BASE)/cygnus/right
CYG_DONGLE_DIR    := $(BUILD_BASE)/cygnus/dongle
CYG_LEFT_SHIELD   := cygnus_left
CYG_RIGHT_SHIELD  := cygnus_right
CYG_DONGLE_SHIELD := cygnus_dongle dongle_screen

# =============================================================================
# Targets
# =============================================================================
.PHONY: help update clean \
        hsv/all hsv/left hsv/right hsv/upload/left hsv/upload/right \
        cygnus/all cygnus/left cygnus/right cygnus/dongle \
        cygnus/upload/left cygnus/upload/right cygnus/upload/dongle

# Default target
all: hsv/all

# -----------------------------------------------------------------------------
# Hillside View
# -----------------------------------------------------------------------------
hsv/all: hsv/left hsv/right

hsv/left:
	$(call build,Hillside View Left,$(HSV_LEFT_DIR),$(BOARD_NICENANO),$(HSV_LEFT_SHIELD),)

hsv/right:
	$(call build,Hillside View Right,$(HSV_RIGHT_DIR),$(BOARD_NICENANO),$(HSV_RIGHT_SHIELD),)

hsv/upload/left:
	$(call upload,Hillside View Left,$(HSV_LEFT_DIR),NICENANO)

hsv/upload/right:
	$(call upload,Hillside View Right,$(HSV_RIGHT_DIR),NICENANO)

# -----------------------------------------------------------------------------
# Cygnus
# -----------------------------------------------------------------------------
cygnus/all: cygnus/left cygnus/right cygnus/dongle

cygnus/left:
	$(call build,Cygnus Left,$(CYG_LEFT_DIR),$(BOARD_NICENANO),$(CYG_LEFT_SHIELD),-DCONFIG_ZMK_SPLIT_ROLE_CENTRAL=n)

cygnus/right:
	$(call build,Cygnus Right,$(CYG_RIGHT_DIR),$(BOARD_NICENANO),$(CYG_RIGHT_SHIELD),)

cygnus/dongle:
	$(call build,Cygnus Dongle,$(CYG_DONGLE_DIR),$(BOARD_XIAO),$(CYG_DONGLE_SHIELD),-DCONFIG_DONGLE_SCREEN_AMBIENT_LIGHT=y)

cygnus/upload/left:
	$(call upload,Cygnus Left,$(CYG_LEFT_DIR),NICENANO)

cygnus/upload/right:
	$(call upload,Cygnus Right,$(CYG_RIGHT_DIR),NICENANO)

cygnus/upload/dongle:
	$(call upload,Cygnus Dongle,$(CYG_DONGLE_DIR),XIAO|SEEED)

# -----------------------------------------------------------------------------
# Maintenance
# -----------------------------------------------------------------------------
update:
	@echo "Updating west dependencies..."
	cd $(ZMK_ROOT)/app && . $(VENV)/bin/activate && west update

clean:
	@echo "Cleaning build directories..."
	rm -rf $(HSV_LEFT_DIR) $(HSV_RIGHT_DIR) $(CYG_LEFT_DIR) $(CYG_RIGHT_DIR) $(CYG_DONGLE_DIR)

# =============================================================================
# Help
# =============================================================================
help:
	@echo "ZMK Firmware Build System"
	@echo ""
	@echo "Hillside View:"
	@echo "  hsv/all                 Build left + right"
	@echo "  hsv/left                Build left (central)"
	@echo "  hsv/right               Build right (peripheral)"
	@echo "  hsv/upload/left         Upload left firmware"
	@echo "  hsv/upload/right        Upload right firmware"
	@echo ""
	@echo "Cygnus:"
	@echo "  cygnus/all              Build left + right + dongle"
	@echo "  cygnus/left             Build left (peripheral)"
	@echo "  cygnus/right            Build right (peripheral)"
	@echo "  cygnus/dongle           Build dongle (central)"
	@echo "  cygnus/upload/left      Upload left firmware"
	@echo "  cygnus/upload/right     Upload right firmware"
	@echo "  cygnus/upload/dongle    Upload dongle firmware"
	@echo ""
	@echo "Maintenance:"
	@echo "  update                  Update west dependencies"
	@echo "  clean                   Remove build artifacts"
	@echo ""
	@echo "Config: ZMK_ROOT=$(ZMK_ROOT)"
	@echo ""
	@echo "Example: make ZMK_ROOT=~/zmk hsv/left hsv/upload/left"
