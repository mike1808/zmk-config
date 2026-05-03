# Ebook Reader Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ZMK module `ebook_reader` shield that displays paginated book text on the Hillside View nice!view display with `&ebook_next` / `&ebook_prev` behaviors.

**Architecture:** Self-contained Zephyr module in `modules/ebook-reader/`. Custom ZMK event decouples behavior (page navigation) from display (LVGL label + progress bar + page number). Text pre-paginated at compile time by Python script.

**Tech Stack:** ZMK/Zephyr, LVGL, C (Zephyr driver model), Python 3 (paginate script), Devicetree

**Spec:** `docs/superpowers/specs/2026-05-02-ebook-reader-design.md`

---

### Task 1: Module scaffold

**Files:**
- Create: `modules/ebook-reader/zephyr/module.yml`
- Create: `modules/ebook-reader/boards/shields/ebook_reader/Kconfig.shield`
- Create: `modules/ebook-reader/boards/shields/ebook_reader/Kconfig.defconfig`
- Create: `modules/ebook-reader/boards/shields/ebook_reader/ebook_reader.conf`
- Create: `modules/ebook-reader/boards/shields/ebook_reader/CMakeLists.txt`
- Create: `modules/ebook-reader/.gitignore`

- [ ] Create `zephyr/module.yml` declaring `board_root: .` (mirror `modules/nice-view-gem/zephyr/module.yml`)
- [ ] Create `Kconfig.shield` declaring `SHIELD_EBOOK_READER` shield
- [ ] Create `Kconfig.defconfig` selecting `ZMK_DISPLAY` and `ZMK_DISPLAY_STATUS_SCREEN_CUSTOM`
- [ ] Create `ebook_reader.conf` enabling display (`CONFIG_ZMK_DISPLAY=y`)
- [ ] Create `CMakeLists.txt` with stubs (empty `target_sources` — fill as files are added)
- [ ] Add `.gitignore` ignoring `boards/shields/ebook_reader/ebook_data.c`
- [ ] Commit: `feat(ebook-reader): scaffold module`

---

### Task 2: Display overlay

**Files:**
- Create: `modules/ebook-reader/boards/shields/ebook_reader/ebook_reader.overlay`

- [ ] Copy SPI + display node config from `modules/nice-view-gem/boards/shields/nice_view_gem/nice_view_gem.overlay`
- [ ] Set `chosen { zephyr,display = &nice_view; }`
- [ ] Commit: `feat(ebook-reader): add display overlay`

---

### Task 3: Custom event `zmk_ebook_page_changed`

**Files:**
- Create: `modules/ebook-reader/boards/shields/ebook_reader/events/ebook_page_changed.h`
- Create: `modules/ebook-reader/boards/shields/ebook_reader/events/ebook_page_changed.c`

- [ ] Define event struct with `uint16_t page_idx` field, following ZMK event pattern (reference `zmk/events/layer_state_changed.h` in ZMK source)
- [ ] Implement `as_zmk_ebook_page_changed()` accessor
- [ ] Add to `CMakeLists.txt`
- [ ] Commit: `feat(ebook-reader): add ebook_page_changed event`

---

### Task 4: Behavior driver `zmk,behavior-ebook-nav`

**Files:**
- Create: `modules/ebook-reader/boards/shields/ebook_reader/behaviors/behavior_ebook_nav.c`

- [ ] Implement Zephyr driver with `compatible = "zmk,behavior-ebook-nav"` and `direction` DT property (0=prev, 1=next)
- [ ] Global `static uint16_t page_idx = 0`
- [ ] `on_binding_pressed`: adjust `page_idx` ±1 clamped to `[0, ebook_total_pages-1]`, raise `zmk_ebook_page_changed` event
- [ ] `on_binding_released`: no-op
- [ ] Add binding to `CMakeLists.txt`
- [ ] Commit: `feat(ebook-reader): add behavior_ebook_nav driver`

---

### Task 5: Book data placeholder

**Files:**
- Create: `modules/ebook-reader/boards/shields/ebook_reader/ebook_data.h`
- Create: `modules/ebook-reader/boards/shields/ebook_reader/ebook_data.c` (placeholder, gitignored)

- [ ] `ebook_data.h`: declare `extern const char *ebook_pages[]; extern const uint16_t ebook_total_pages;`
- [ ] `ebook_data.c` placeholder: 3-page stub with short sample text so build compiles before real book is paginated
- [ ] Add to `CMakeLists.txt`
- [ ] Commit: `feat(ebook-reader): add ebook_data placeholder`

---

### Task 6: Display screen

**Files:**
- Create: `modules/ebook-reader/boards/shields/ebook_reader/custom_status_screen.c`

- [ ] Implement `zmk_display_status_screen()` — create LVGL objects on 160×68 screen (no canvas rotation):
  - `lv_label` text area: x=0 y=0 w=160 h=60, `pixel_operator_mono`, `LV_LABEL_LONG_CLIP`
  - `lv_bar` progress: x=4 y=60 w=124 h=8 (4px left pad)
  - `lv_label` page number: x=132 y=60 w=24 h=8, right-aligned, `pixel_operator_mono`, format `"%d"` (4px gap after bar, 4px right pad)
- [ ] Subscribe to `zmk_ebook_page_changed` via `ZMK_DISPLAY_WIDGET_LISTENER`: update label text, bar value (`page_idx * 100 / total_pages`), page number label (`snprintf "%d", page_idx + 1`)
- [ ] Add to `CMakeLists.txt`
- [ ] Commit: `feat(ebook-reader): add display screen`

---

### Task 7: `paginate.py` script

**Files:**
- Create: `modules/ebook-reader/tools/paginate.py`

- [ ] CLI args: `--input`, `--output`, `--chars-per-line` (default 20), `--lines-per-page` (default 8)
- [ ] Strip Project Gutenberg header/footer boilerplate (lines before `*** START` / after `*** END`)
- [ ] Normalize whitespace, preserve paragraph breaks as blank lines between pages
- [ ] Word-wrap to `chars-per-line`, split into pages of `lines-per-page`
- [ ] Emit valid C: `#include "ebook_data.h"` + `const char *ebook_pages[] = {...}` + `const uint16_t ebook_total_pages = N;`
- [ ] Escape special chars in strings (`\n` for newlines, `\"`, `\\`)
- [ ] Commit: `feat(ebook-reader): add paginate.py`

---

### Task 8: Build integration

**Files:**
- Modify: `build.yaml`
- Modify: `config/hillside_view.keymap` (add `&ebook_next` / `&ebook_prev` bindings to a combo or layer)
- Modify: `Makefile` (add convenience alias `ebook/left`)

- [ ] Add entry to `build.yaml`:
  ```yaml
  - board: nice_nano
    shield: hillside_view_left ebook_reader
    snippet: studio-rpc-usb-uart
  ```
- [ ] Add `ebook/left` and `ebook/upload/left` convenience aliases to `Makefile`
- [ ] Add `&ebook_next` / `&ebook_prev` key combo bindings in `hillside_view.keymap`
- [ ] Commit: `feat(ebook-reader): wire build and keymap`

---

### Task 9: End-to-end build + real book

**Files:**
- Create: `modules/ebook-reader/books/` (directory, add chosen `.txt`)

- [ ] Pick a short public domain book from Project Gutenberg (e.g. *The Metamorphosis* ~60KB)
- [ ] Commit the `.txt` to `modules/ebook-reader/books/`
- [ ] Run `python3 modules/ebook-reader/tools/paginate.py --input modules/ebook-reader/books/<book>.txt --output modules/ebook-reader/boards/shields/ebook_reader/ebook_data.c`
- [ ] Run `make ebook/left` and verify build succeeds (check for linker errors, memory usage)
- [ ] Flash and verify display shows text landscape, progress bar moves, page number updates
- [ ] Commit: `feat(ebook-reader): add The Metamorphosis, verify build`
