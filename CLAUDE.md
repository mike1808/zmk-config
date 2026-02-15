# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a ZMK firmware configuration repository for custom split mechanical keyboards. It contains configurations for two main keyboards: **Hillside View** and **Cygnus**. The repository uses GitHub Actions to automatically build firmware images.

## Architecture

### Repository Structure

- `config/` - Main configuration directory containing keymaps and board definitions
  - `*.keymap` - User-facing keymap files (hillside_view.keymap, cygnus.keymap)
  - `*.conf` - Configuration files for keyboard features
  - `*.json` - Keymap editor JSON exports (editable via https://nickcoutsos.github.io/keymap-editor/)
  - `boards/shields/` - Shield definitions for each keyboard
    - `hillside_view/` - Hillside View hardware definitions (.dtsi, .overlay, Kconfig files)
    - `cygnus/` - Cygnus hardware definitions
  - `west.yml` - West manifest defining ZMK version and module dependencies

- `build.yaml` - Build matrix configuration defining which board+shield combinations to build

- `.github/workflows/` - GitHub Actions workflows for automated firmware builds

### ZMK Version

This repository uses ZMK `main` branch in `config/west.yml`. To pin to a specific commit:
1. Change the `revision` field from `main` to a specific commit hash
2. Test the build to ensure compatibility
3. Update both `config/west.yml` and the ZMK build directory's `west.yml` if building locally

### Build System

Builds are defined in `build.yaml` and run via GitHub Actions. The build matrix includes:
- **Hillside View**: Split keyboard with nice!nano v2, nice_view_gem display and studio-rpc-usb-uart snippet
- **Cygnus**: Split keyboard with nice!nano v2 peripherals and Seeeduino XIAO BLE dongle with screen
- **Settings Reset**: Utility builds for both nice!nano v2 and Seeeduino XIAO BLE

Build outputs are generated as firmware artifacts by the GitHub Actions workflow.

### External Dependencies

The repository uses several ZMK modules defined in `config/west.yml`:
- `nice-view-gem` (M165437) - Nice!View custom display widgets with animations
- `prospector-zmk-module` (carrefinho) - Status screen widgets and sensor support for Cygnus dongle

**Note:** Split peripheral input relay is now built into ZMK core as `zmk,input-split` (since PR #2477, Dec 2024)

### Keyboard-Specific Features

**Hillside View:**
- 46-key split keyboard with Nice!View e-paper display (nice-view-gem custom widgets)
- Custom display status screen on left (central) side with `CONFIG_ZMK_DISPLAY_STATUS_SCREEN_CUSTOM=y`
- Display disabled on right (peripheral) side (`CONFIG_ZMK_DISPLAY=n`) to save resources
- Cirque Glidepoint trackpad on right (peripheral) side relayed via `zmk,input-split`
- Input processors for y-axis inversion and 2x scaling
- Temporary mouse layer (MOUSE) activates during trackpad movement (300ms timeout)
  - Right click on left thumb key (position 41, was LEFT_ALT)
  - Left click on right thumb key (position 42, was RIGHT_ALT)
- Trackpad uses I2C bus on peripheral with DR (data ready) GPIO
- Conditional layer activation (ADJ layer activates when both SYM and NUM are held)

**Cygnus:**
- Split keyboard with dongle configuration
- Dongle uses Seeeduino XIAO BLE with `prospector_adapter` shield for status screen display
- Split peripherals use `CONFIG_ZMK_SPLIT_ROLE_CENTRAL=n` for left side
- Gaming layer (GAM) in addition to standard layers

### Keymap Patterns

Both keyboards follow similar patterns:
- Layer definitions: DEF (default), SYM (symbols), NUM (numbers), ADJ (adjust), MOUSE (temp mouse clicks)
- Home row mods with custom behaviors (`hml`, `hmr`)
- Hold-tap behaviors with quick-tap configuration (175ms quick-tap, 150-200ms tapping term)
- Sticky keys with 600ms release-after
- Caps word combos for quick capitalization
- Custom bootloader tap-dance behavior
- Temporary layers activated by input processors (e.g., MOUSE layer during trackpad movement)

## Build and Development

### Building Firmware

**Automated builds:** Firmware builds automatically on push/PR via GitHub Actions. The build workflow outputs `.uf2` files for flashing to keyboards.

**Local builds:** Use the provided Makefile for simplified builds:

```bash
# First time setup: Clone external modules
make modules/setup ZMK_ROOT=~/workspace/dactyl/zmk

# Build commands
make hsv/left ZMK_ROOT=~/workspace/dactyl/zmk
make hsv/right ZMK_ROOT=~/workspace/dactyl/zmk

# Or set ZMK_ROOT permanently
export ZMK_ROOT=~/workspace/dactyl/zmk
make hsv/all

# Firmware output: <zmk-root>/app/build/hsv/{left,right}/zephyr/zmk.uf2
```

**Manual builds (advanced):**
```bash
cd <zmk-root>/app
source <zmk-root>/.venv/bin/activate

# Build with external modules
west build -p -d build/hsv/left -b nice_nano \
  -- -DSHIELD="hillside_view_left nice_view_gem" \
     -DZMK_CONFIG=$(realpath <config-path>/config/) \
     -DZMK_EXTRA_MODULES="<modules-path>/zmk-dongle-screen:<modules-path>/nice-view-gem:..."
```

**Required Python packages in venv:**
- `west`
- `pyelftools`
- `setuptools`
- `protobuf`
- `grpcio-tools`

**External Modules Setup:**

This repository uses `ZMK_EXTRA_MODULES` instead of modifying ZMK's west.yml:
1. Run `make modules/setup` to clone all external modules to `./modules/`
2. Build commands automatically include `-DZMK_EXTRA_MODULES` pointing to cloned modules
3. Update modules with `make modules/update`

**Modules included:**
- `nice-view-gem` (M165437/main) - Custom display widgets with animations
- `prospector-zmk-module` (carrefinho/feat/new-status-screens) - Status screen support for Cygnus dongle

**Build flags:**
- `-p` = pristine build (clean)
- `-d <dir>` = build directory
- `-b <board>` = board name (nice_nano for v2.0+, xiao_ble)
- `-DSHIELD` = shield(s) to build
- `-DZMK_CONFIG` = path to this config repository
- `-DZMK_EXTRA_MODULES` = colon-separated paths to external modules

**Board Names (Zephyr 4.1+):**
- Use `nice_nano` (not nice_nano_v2)
- Use `nice_view_gem` for display shield (custom widgets with animations)

**Tip:** Use `grep -E "(Wrote|FAILED|error:|Memory region)"` to filter build output and save tokens.

**Makefile Usage:**

The Makefile reads all build configurations from `build.yaml` (single source of truth). Targets use the format `build/<first_shield>-<board>` or convenience aliases.

```bash
# Set ZMK_ROOT in Makefile or as environment variable
export ZMK_ROOT=~/path/to/zmk

# List all available targets from build.yaml
make list

# Build using direct targets (read from build.yaml)
make build/hillside_view_left-nice_nano
make build/cygnus_dongle-xiao_ble

# Or use convenience aliases
# Hillside View
make hsv/all              # Build left + right
make hsv/left             # Build left (central)
make hsv/right            # Build right (peripheral)
make hsv/upload/left      # Upload left firmware
make hsv/upload/right     # Upload right firmware

# Cygnus
make cygnus/all           # Build left + right + dongle
make cygnus/left          # Build left (peripheral)
make cygnus/right         # Build right (peripheral)
make cygnus/dongle        # Build dongle (central)
make cygnus/upload/left   # Upload left firmware
make cygnus/upload/right  # Upload right firmware
make cygnus/upload/dongle # Upload dongle firmware

# Maintenance
make update               # Update west dependencies
make clean                # Clean build artifacts
make help                 # Show help

# Chain commands
make hsv/left hsv/upload/left   # Build and upload in one command
```

**Makefile Implementation Details:**

The Makefile dynamically reads `build.yaml` to generate build targets:
- Uses `yq` to parse board, shield, cmake-args, and snippet fields
- Consolidates multiple yq calls into single invocations for efficiency (4→1 for build, 2→1 for upload, 3N+1→1 for modules/setup)
- Validates firmware exists before upload attempt
- Auto-discovers external modules from `./modules/` directory
- Provides both explicit targets (`build/<shield>-<board>`) and convenience aliases (`hsv/left`)

**Adding new keyboards to build.yaml:**
1. Add entry to `build.yaml` include list with board, shield, and optional cmake-args/snippet
2. Run `make list` to verify the new target appears
3. Build with `make build/<first_shield>-<board>` or add convenience alias to Makefile

### Editing Keymaps

1. Edit `.keymap` files directly in `config/` for code-level changes
2. Use the keymap editor (https://nickcoutsos.github.io/keymap-editor/) for visual editing
   - Export from editor updates the `.json` files
   - Manual synchronization between `.json` and `.keymap` may be needed

### Configuration Changes

- Keyboard features: Edit `.conf` files in `config/`
- Build matrix: Edit `build.yaml` to add/remove build targets
- Hardware definitions: Edit files in `config/boards/shields/<keyboard>/`
- ZMK modules: Modify `config/west.yml` to change dependencies or ZMK version

### Adding New Keyboards

1. Create shield directory in `config/boards/shields/<keyboard_name>/`
2. Add hardware definition files (`.dtsi`, `.overlay`, Kconfig files)
3. Create keymap files in `config/` root
4. Update `build.yaml` to include new build targets

## Common Patterns

### Layer Management
Use conditional layers for automatic activation (e.g., ADJ activates when SYM+NUM are both active).

### Custom Behaviors
Define behaviors in the `behaviors` node with clear labels. Common patterns include:
- `lq` - Layer toggle quick (tap-preferred)
- `ht` - Hold tap (tap-preferred)
- `hml`/`hmr` - Home row mods (left/right)
- `bootldr` - Tap-dance to bootloader

### Input Processing (Split Peripherals)
For trackpads on split peripherals, use the integrated `zmk,input-split`:

1. **Shared .dtsi file:**
   - Define `zmk,input-split` device with unique `reg` value
   - Define `zmk,input-listener` (disabled by default) referencing the split device

2. **Peripheral overlay:**
   - Override split device with `device = <&physical_trackpad>`

3. **Central overlay:**
   - Enable the listener with `status = "okay"`

4. **Input processors:**
   - Include `<input/processors.dtsi>` in keymap
   - Use `&zip_xy_transform` for axis transformations (invert, swap)
   - Use `&zip_xy_scaler` for sensitivity scaling (multiplier, divisor)
   - Use `&zip_temp_layer` for temporary layer activation (layer_number, timeout_ms)
   - Apply via `input-processors` property on listener nodes

### Temporary Layers with Pointing Devices

To enable a temporary layer during pointer movement:

1. **Include pointing header:**
   ```c
   #include <dt-bindings/zmk/pointing.h>
   ```

2. **Add temp_layer processor to input listener:**
   ```c
   input-processors = <&zip_temp_layer LAYER_NUM TIMEOUT_MS>;
   ```
   - `LAYER_NUM`: Layer index to activate (e.g., 4 for MOUSE layer)
   - `TIMEOUT_MS`: Duration to keep layer active after last movement (e.g., 300)

3. **Create layer with mouse click bindings:**
   ```c
   mouse_layer {
       bindings = <
           &trans  &trans  &mkp LCLK  &mkp RCLK  // ... positions
       >;
   };
   ```

**Mouse Click Defines:**
- `&mkp LCLK` - Left click (MB1)
- `&mkp RCLK` - Right click (MB2)
- `&mkp MCLK` - Middle click (MB3)
- `&mkp MB4` - Back button
- `&mkp MB5` - Forward button

**Example:** Hillside View uses 300ms timeout for near-instant layer deactivation when trackpad movement stops.
