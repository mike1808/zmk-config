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
- **Hillside View**: Split keyboard with nice!nano v2, nice_epaper display and studio-rpc-usb-uart snippet
- **Cygnus**: Split keyboard with nice!nano v2 peripherals and Seeeduino XIAO BLE dongle with screen
- **Settings Reset**: Utility builds for both nice!nano v2 and Seeeduino XIAO BLE

Build outputs are generated as firmware artifacts by the GitHub Actions workflow.

### External Dependencies

The repository uses several ZMK modules defined in `config/west.yml`:
- `cirque-input-module` (badjeff) - Cirque Glidepoint trackpad support for I2C
- `zmk-dongle-screen` (janpfischer) - Dongle display support for Cygnus
- `prospector-zmk-module` (badjeff) - Additional sensor support
- `zmk-pmw3610-driver` (badjeff) - PMW3610 optical sensor driver

**Note:** Split peripheral input relay is now built into ZMK core as `zmk,input-split` (since PR #2477, Dec 2024)

### Keyboard-Specific Features

**Hillside View:**
- 46-key split keyboard with Nice!View e-paper display 
- Cirque Glidepoint trackpad on right (peripheral) side relayed via `zmk,input-split`
- Input processors for y-axis inversion and 2x scaling
- Trackpad uses I2C bus on peripheral with DR (data ready) GPIO
- Conditional layer activation (ADJ layer activates when both SYM and NUM are held)

**Cygnus:**
- Split keyboard with dongle configuration
- Dongle uses Seeeduino XIAO BLE with ambient light sensor support (`CONFIG_DONGLE_SCREEN_AMBIENT_LIGHT=y`)
- Split peripherals use `CONFIG_ZMK_SPLIT_ROLE_CENTRAL=n` for left side
- Gaming layer (GAM) in addition to standard layers

### Keymap Patterns

Both keyboards follow similar patterns:
- Layer definitions: DEF (default), SYM (symbols), NUM (numbers), ADJ (adjust)
- Home row mods with custom behaviors (`hml`, `hmr`)
- Hold-tap behaviors with quick-tap configuration (175ms quick-tap, 150-200ms tapping term)
- Sticky keys with 600ms release-after
- Caps word combos for quick capitalization
- Custom bootloader tap-dance behavior

## Build and Development

### Building Firmware

**Automated builds:** Firmware builds automatically on push/PR via GitHub Actions. The build workflow outputs `.uf2` files for flashing to keyboards.

**Local builds:** For testing changes before pushing:

```bash
# Navigate to ZMK app directory (adjust path to your ZMK installation)
cd <zmk-root>/app

# Activate Python virtual environment with west
source <zmk-root>/.venv/bin/activate

# Update dependencies (run after modifying west.yml)
west update

# Build left side (Hillside View example)
west build -p -d build/hsv/left -b nice_nano_v2 -S studio-rpc-usb-uart \
  -- -DSHIELD="hillside_view_left nice_epaper" \
     -DZMK_CONFIG=$(realpath <path-to-zmk-config>/config/)

# Build right side
west build -p -d build/hsv/right -b nice_nano_v2 \
  -- -DSHIELD="hillside_view_right" \
     -DZMK_CONFIG=$(realpath <path-to-zmk-config>/config/)

# Firmware output: build/hsv/{left,right}/zephyr/zmk.uf2
```

**Required Python packages in venv:**
- `west`
- `pyelftools`
- `setuptools`
- `protobuf`
- `grpcio-tools`

**Build flags:**
- `-p` = pristine build (clean)
- `-d <dir>` = build directory
- `-b <board>` = board name (nice_nano_v2, seeeduino_xiao_ble)
- `-S <snippet>` = snippet (studio-rpc-usb-uart for ZMK Studio support)
- `-DSHIELD` = shield(s) to build
- `-DZMK_CONFIG` = path to this config repository

**Tip:** Use `grep -E "(Wrote|FAILED|error:|Memory region)"` to filter build output and save tokens.

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
   - Apply via `input-processors` property on listener nodes
