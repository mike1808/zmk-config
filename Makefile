# ZMK Firmware Local Build Configuration
ZMK_ROOT ?= $(HOME)/path/to/zmk
VENV ?= $(ZMK_ROOT)/.venv
CONFIG_PATH := $(CURDIR)/config
BUILD_BASE := $(ZMK_ROOT)/app/build
BUILD_YAML := $(CURDIR)/build.yaml
UPLOAD_TIMEOUT ?= 60

# External modules directory
MODULES_DIR := $(CURDIR)/modules
WEST_YML := $(CONFIG_PATH)/west.yml

# =============================================================================
# Build targets derived from build.yaml
# Target name format: <first_shield>-<board>
# =============================================================================
BUILDS := $(shell yq -r '.include[] | ((.shield | split(" ") | .[0]) + "-" + .board)' $(BUILD_YAML) 2>/dev/null)

# Group builds by keyboard prefix
HSV_BUILDS := $(filter hillside_view_%,$(BUILDS))
CYG_BUILDS := $(filter cygnus_%,$(BUILDS))

# yq filter: select build.yaml entry by target name (set $$target in shell first)
YQ_SELECT = .include[] | select(((.shield | split(\" \") | .[0]) + \"-\" + .board) == \"$$target\")

# =============================================================================
# Phony targets
# =============================================================================
.PHONY: all list help update clean \
        hsv/all hsv/left hsv/right hsv/upload/left hsv/upload/right \
        cygnus/all cygnus/left cygnus/right cygnus/dongle \
        cygnus/upload/left cygnus/upload/right cygnus/upload/dongle \
        modules/setup modules/update modules/clean

all: $(addprefix build/,$(BUILDS))

# =============================================================================
# build/<first_shield>-<board>
# All parameters (board, shield, cmake-args, snippet) read from build.yaml
# =============================================================================
build/%:
	@target="$*"; \
	eval $$(yq -r "$(YQ_SELECT) | \"board=\" + (.board | @sh) + \" shield=\" + (.shield | @sh) + \" cmake_args=\" + ((.[\"cmake-args\"] // \"\") | @sh) + \" snippet=\" + ((.snippet // \"\") | @sh)" $(BUILD_YAML)); \
	if [ -z "$$board" ]; then \
		echo "Error: '$$target' not found in $(BUILD_YAML)"; \
		echo "Run 'make list' to see available targets"; \
		exit 1; \
	fi; \
	snippet_args=""; \
	for s in $$snippet; do snippet_args="$$snippet_args -S $$s"; done; \
	echo "Building $$shield ($$board)..."; \
	modules=$$(find $(MODULES_DIR) -mindepth 1 -maxdepth 1 -type d 2>/dev/null | paste -sd';'); \
	cd $(ZMK_ROOT)/app && \
	. $(VENV)/bin/activate && \
	west build -p -d "$(BUILD_BASE)/$$target" -b "$$board" $$snippet_args \
		-- -DSHIELD="$$shield" -DZMK_CONFIG=$(CONFIG_PATH) \
		$${modules:+-DZMK_EXTRA_MODULES="$$modules"} $$cmake_args

# =============================================================================
# upload/<first_shield>-<board>
# Detects bootloader device and flashes firmware
# =============================================================================
upload/%:
	@target="$*"; \
	eval $$(yq -r "$(YQ_SELECT) | \"board=\" + (.board | @sh) + \" shield=\" + (.shield | @sh)" $(BUILD_YAML)); \
	if [ -z "$$board" ]; then \
		echo "Error: '$$target' not found in $(BUILD_YAML)"; \
		echo "Run 'make list' to see available targets"; \
		exit 1; \
	fi; \
	fw="$(BUILD_BASE)/$$target/zephyr/zmk.uf2"; \
	if [ ! -f "$$fw" ]; then echo "Error: Firmware not found at $$fw (run build first)"; exit 1; fi; \
	case "$$board" in \
		nice_nano) pattern="NICENANO";; \
		xiao_ble|xiao_ble//zmk) pattern="XIAO|SEEED";; \
		*) echo "Error: No device pattern for board '$$board' - update Makefile"; exit 1;; \
	esac; \
	echo "Waiting for bootloader device..."; \
	echo "Please connect $$shield in bootloader mode"; \
	timeout=$(UPLOAD_TIMEOUT); elapsed=0; device=""; \
	while [ -z "$$device" ] && [ $$elapsed -lt $$timeout ]; do \
		device=$$(lsblk -no NAME,LABEL 2>/dev/null | grep -E "$$pattern" | awk '{print "/dev/"$$1}'); \
		[ -z "$$device" ] && sleep 1 && elapsed=$$((elapsed + 1)); \
	done; \
	if [ -z "$$device" ]; then echo "Error: Device not found after $(UPLOAD_TIMEOUT)s"; exit 1; fi; \
	echo "Device: $$device"; \
	mount_point=$$(lsblk -no MOUNTPOINT $$device 2>/dev/null | head -1); \
	if [ -z "$$mount_point" ]; then \
		echo "Mounting device..."; \
		mount_point=$$(udisksctl mount -b $$device 2>&1 | grep -oP 'at \K.*'); \
	else \
		echo "Already mounted"; \
	fi; \
	if [ -z "$$mount_point" ] || [ ! -d "$$mount_point" ]; then echo "Error: Mount failed"; exit 1; fi; \
	echo "Mount point: $$mount_point"; \
	until cp "$$fw" "$$mount_point/"; do echo "Retrying..."; sleep 1; done; \
	sync; echo "$$shield uploaded successfully"

# =============================================================================
# Aliases
# =============================================================================
hsv/all: $(addprefix build/,$(HSV_BUILDS))
cygnus/all: $(addprefix build/,$(CYG_BUILDS))

hsv/left:           build/hillside_view_left-nice_nano
hsv/right:          build/hillside_view_right-nice_nano
hsv/upload/left:    upload/hillside_view_left-nice_nano
hsv/upload/right:   upload/hillside_view_right-nice_nano

cygnus/left:          build/cygnus_left-nice_nano
cygnus/right:         build/cygnus_right-nice_nano
cygnus/dongle:        build/cygnus_dongle-xiao_ble//zmk
cygnus/upload/left:   upload/cygnus_left-nice_nano
cygnus/upload/right:  upload/cygnus_right-nice_nano
cygnus/upload/dongle: upload/cygnus_dongle-xiao_ble//zmk

# =============================================================================
# List available targets
# =============================================================================
list:
	@echo "Available builds (from build.yaml):"
	@yq -r '.include[] | "  build/" + ((.shield | split(" ") | .[0]) + "-" + .board) + "\t" + .shield + " (" + .board + ")"' $(BUILD_YAML) | column -t -s '	'
	@echo ""
	@echo "Groups:"
	@echo "  hsv/all                 Hillside View builds"
	@echo "  cygnus/all              Cygnus builds"
	@echo "  all                     All builds"
	@echo ""
	@echo "Upload: replace 'build/' with 'upload/' (e.g. upload/cygnus_left-nice_nano)"

# =============================================================================
# Maintenance
# =============================================================================
update:
	@echo "Updating west dependencies..."
	cd $(ZMK_ROOT)/app && . $(VENV)/bin/activate && west update

clean:
	@echo "Cleaning build directories..."
	@for target in $(BUILDS); do rm -rf "$(BUILD_BASE)/$$target"; done
	@echo "Build directories cleaned"

# =============================================================================
# External Modules
# =============================================================================
modules/setup:
	@echo "Setting up external modules from $(WEST_YML)..."
	@command -v yq >/dev/null 2>&1 || { echo "Error: yq is required. Install with: brew install yq / apt install yq"; exit 1; }
	@mkdir -p $(MODULES_DIR)
	@yq -r '.manifest | . as $$m | .projects[] | select(.name == "zmk" | not) | . as $$p | $$m.remotes[] | select(.name == $$p.remote) | [$$p.name, .["url-base"], $$p.revision] | @tsv' $(WEST_YML) | while read -r name url_base revision; do \
		if [ -d "$(MODULES_DIR)/$$name" ]; then \
			echo "$$name already exists"; \
		else \
			echo "Cloning $$name ($$revision) from $$url_base..."; \
			git clone -b $$revision $$url_base/$$name.git $(MODULES_DIR)/$$name || exit 1; \
		fi; \
	done
	@echo "Modules setup complete"

modules/update:
	@echo "Updating external modules..."
	@if [ ! -d "$(MODULES_DIR)" ]; then echo "Error: Run 'make modules/setup' first"; exit 1; fi
	@for dir in $(MODULES_DIR)/*; do \
		if [ -d "$$dir/.git" ]; then \
			echo "Updating $$(basename $$dir)..."; \
			cd $$dir && git pull || echo "Warning: Failed to update $$(basename $$dir)"; \
		fi; \
	done
	@echo "Modules updated"

modules/clean:
	@echo "Removing all external modules..."
	@rm -rf $(MODULES_DIR)
	@echo "Modules removed"

# =============================================================================
# Help
# =============================================================================
help:
	@echo "ZMK Firmware Build System"
	@echo ""
	@echo "Builds are derived from $(BUILD_YAML)"
	@echo ""
	@echo "Commands:"
	@echo "  list                    Show available build targets"
	@echo "  all                     Build all targets"
	@echo "  build/<name>            Build a specific target"
	@echo "  upload/<name>           Upload firmware to device"
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
	@echo "Modules:"
	@echo "  modules/setup           Clone external modules from west.yml"
	@echo "  modules/update          Update all cloned modules"
	@echo "  modules/clean           Remove all modules"
	@echo ""
	@echo "Maintenance:"
	@echo "  update                  Update west dependencies"
	@echo "  clean                   Remove build artifacts"
	@echo ""
	@echo "Config: ZMK_ROOT=$(ZMK_ROOT)"
	@echo "        MODULES_DIR=$(MODULES_DIR)"
	@echo ""
	@echo "Example: make modules/setup ZMK_ROOT=~/zmk"
	@echo "         make build/cygnus_left-nice_nano upload/cygnus_left-nice_nano"
