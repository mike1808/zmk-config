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

### ZMK Version Pinning

This repository pins ZMK to a specific commit (`abb64ba316c29caddc49caddc49727ca2cac2f0ed5970c7`) in `config/west.yml`. This ensures consistent builds. To update ZMK:
1. Change the `revision` field in `config/west.yml`
2. Test the build to ensure compatibility
3. The commit message pattern suggests using descriptive messages like "pin zmk version to pre 4.1"

### Build System

Builds are defined in `build.yaml` and run via GitHub Actions. The build matrix includes:
- **Hillside View**: Split keyboard with nice!nano v2, nice_view display, and studio-rpc-usb-uart snippet
- **Cygnus**: Split keyboard with nice!nano v2 peripherals and Seeeduino XIAO BLE dongle with screen
- **Settings Reset**: Utility builds for both nice!nano v2 and Seeeduino XIAO BLE

Build outputs are generated as firmware artifacts by the GitHub Actions workflow.

### External Dependencies

The repository uses several ZMK modules defined in `config/west.yml`:
- `zmk-split-peripheral-input-relay` (badjeff) - For split keyboard input relay
- `cirque-input-module` (badjeff) - Cirque trackpad support
- `zmk-dongle-screen` (janpfischer) - Dongle display support

### Keyboard-Specific Features

**Hillside View:**
- 46-key split keyboard with sharp display support
- Cirque Glidepoint trackpad integration (both central and peripheral)
- Input listeners for mouse movement and scrolling
- Custom layer-dependent trackpad behavior (mouse mode on DEF/SYM/ADJ layers, scroll mode on NUM layer)
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

Firmware builds automatically on push/PR via GitHub Actions. To manually trigger a build:
```bash
# Push to repository or use GitHub Actions UI to manually trigger workflow_dispatch
```

The build workflow outputs `.uf2` files for flashing to keyboards.

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

### Input Processing
For trackpads/pointing devices:
- Define `input-behavior-listener` nodes
- Configure per-layer behavior using `layers` property
- Use `input-behavior-scaler` for scroll acceleration
