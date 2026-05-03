# Ebook Reader — Design Spec

**Date:** 2026-05-02  
**Status:** Approved

## Overview

A dedicated ZMK firmware build for the Hillside View keyboard that turns the nice!view display into a landscape e-ink book reader. Text displayed horizontally (160×64px), 4px progress bar at bottom. Navigation via custom `&ebook_next` / `&ebook_prev` ZMK behaviors mapped to key combos.

## Constraints

- Display: Sharp LS0XX memory LCD, 160×68px, 1bpp
- MCU: nRF52840 — 1MB flash, 256KB RAM (ZMK uses most of RAM)
- No filesystem — text compiled into firmware as C array
- Dedicated build only (separate build.yaml entry, not toggled at runtime)

## Module Structure

Self-contained Zephyr module at `modules/ebook-reader/`, auto-discovered by the Makefile alongside other modules.

```
modules/ebook-reader/
  zephyr/module.yml
  boards/shields/ebook_reader/
    Kconfig.shield
    Kconfig.defconfig
    ebook_reader.conf
    ebook_reader.overlay         # enables nice_view SPI, sets zephyr,display = &nice_view
    CMakeLists.txt
    custom_status_screen.c       # zmk_display_status_screen() implementation
    events/
      ebook_page_changed.h
      ebook_page_changed.c       # custom ZMK event: carries uint16_t page_idx
    behaviors/
      behavior_ebook_nav.c       # zmk,behavior-ebook-nav driver
    ebook_data.h                 # declares extern pages[] and total_pages
    ebook_data.c                 # generated — gitignored
  tools/
    paginate.py                  # txt → ebook_data.c
```

## Data Pipeline

`tools/paginate.py` converts a plain-text book into a C source file.

**Inputs (CLI args):**

- `--input book.txt`
- `--output boards/shields/ebook_reader/ebook_data.c`
- `--chars-per-line 20` (default, configurable for font size)
- `--lines-per-page 8` (default, configurable)

**Script logic:**

1. Normalize whitespace, strip BOM/Project Gutenberg boilerplate
2. Word-wrap each paragraph to `chars-per-line`
3. Split wrapped lines into pages of `lines-per-page`
4. Emit C array

**Output shape:**

```c
#include "ebook_data.h"

const char *ebook_pages[] = {
    "Once upon a time\na dark and stormy\n...",
    /* ... */
};
const uint16_t ebook_total_pages = 342;
```

`ebook_data.c` is gitignored. source `.txt` (public domain, project gutenberg) is committed. Don't generate the .txt, user will provide it.

## ZMK Behavior: `zmk,behavior-ebook-nav`

Single devicetree property: `direction` — `0` = previous, `1` = next.

**Keymap usage:**

```dts
/ {
    behaviors {
        ebook_next: ebook_next {
            compatible = "zmk,behavior-ebook-nav";
            direction = <1>;
        };
        ebook_prev: ebook_prev {
            compatible = "zmk,behavior-ebook-nav";
            direction = <0>;
        };
    };
};
```

**Driver behavior:**

- `on_binding_pressed`: adjust global `page_idx` by ±1, clamped to `[0, total_pages-1]`, fire `zmk_ebook_page_changed(page_idx)`
- `on_binding_released`: no-op

Map `&ebook_next` / `&ebook_prev` to key combos in `hillside_view.keymap`.

## Custom Event: `zmk_ebook_page_changed`

Standard ZMK event pattern carrying `uint16_t page_idx`. Fired by behavior, consumed by display listener. Keeps behavior and display decoupled.

## Display Screen

`custom_status_screen.c` implements `zmk_display_status_screen()` — replaces nice-view-gem's version (not included in this build).

**Layout (landscape, no canvas rotation):**

```
┌──────────────────────────────────────────────────────────────────┐ y=0
│                                                                  │
│  lv_label  160×60px  pixel_operator_mono  LV_LABEL_LONG_CLIP    │
│                                                                  │
├────────────────────────────────────────────────────────┬─────────┤ y=60
│  lv_bar  ~135px wide  progress (0–100%)                │  "42"   │ 8px
└────────────────────────────────────────────────────────┴─────────┘ y=68
```

Bottom strip (y=60..68, 8px tall), 4px horizontal padding each side:
- Progress bar: x=4, w=124, h=8
- Page number label: x=132, w=24, h=8, right-aligned, `pixel_operator_mono`, format `"%d"` (page number only, no total)
- 4px gap between bar right edge and page number left edge

**Listener on `zmk_ebook_page_changed`:**

1. `lv_label_set_text(label, ebook_pages[page_idx])`
2. `lv_bar_set_value(bar, page_idx * 100 / total_pages, LV_ANIM_OFF)`
3. Update page number label: `snprintf(buf, sizeof(buf), "%d", page_idx + 1)`

## Build Integration

New `build.yaml` entry (no `nice_view_gem` — would conflict on `zmk_display_status_screen`):

```yaml
- board: nice_nano
  shield: hillside_view_left ebook_reader
  snippet: studio-rpc-usb-uart
  cmake-args: -DCONFIG_ZMK_DISPLAY_STATUS_SCREEN_CUSTOM=y
```

`ebook_reader.overlay` initializes the Sharp display directly (same config as `nice_view_gem.overlay`) so the display hardware is available without that shield.

Makefile auto-discovers `modules/ebook-reader/` via the existing `modules/` glob — no Makefile changes needed.

## Out of Scope (V1)

- Multiple books / runtime book selection
- Bookmarks persisted to flash settings
- Font size toggle
- BLE-based text transfer
