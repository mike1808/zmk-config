# Modifier Widget for nice-view-gem Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a modifier indicator widget (⇧ ⌃ ⌥ ⌘ with Caps Word support) to nice-view-gem's middle canvas as a Kconfig-selectable alternative to the WPM gauge.

**Architecture:** Canvas-based drawing following the existing `draw_wpm_status()` pattern. All rendering is in a new `modifiers.c` file, toggled by `CONFIG_NICE_VIEW_GEM_MODIFIERS`. Uses Mac-style symbols copied from prospector's Symbols_Bold_26.c (4bpp, renders fine on L8 canvas). Event subscription mirrors prospector's modifier widget approach via `zmk_hid_get_explicit_mods()`.

**Tech Stack:** ZMK firmware, LVGL v9, Zephyr RTOS, C, Kconfig

---

## File Map

All files under `modules/nice-view-gem/boards/shields/nice_view_gem/`:

| Action | File | Purpose |
|--------|------|---------|
| Copy | `assets/Symbols_Bold_26.c` | Modifier symbol font (from prospector) |
| Create | `widgets/modifiers.h` | `draw_modifier_status()` declaration |
| Create | `widgets/modifiers.c` | Canvas drawing + event subscription |
| Modify | `widgets/util.h:34` | Add `mods[4]` + `caps_word` to `status_state` |
| Modify | `widgets/screen.c` | Conditional include/draw/subscribe/init |
| Modify | `CMakeLists.txt:13` | Conditional modifiers.c vs wpm.c |
| Modify | `Kconfig.defconfig:60-65` | New option + conditional ZMK_WPM select |

---

## Task 1: Copy symbol font from prospector

**Files:**
- Create: `modules/nice-view-gem/boards/shields/nice_view_gem/assets/Symbols_Bold_26.c`

- [ ] **Step 1: Copy the font file**

```bash
cp modules/prospector-zmk-module/boards/shields/prospector_adapter/src/fonts/Symbols_Bold_26.c \
   modules/nice-view-gem/boards/shields/nice_view_gem/assets/Symbols_Bold_26.c
```

- [ ] **Step 2: Verify the copy**

```bash
head -6 modules/nice-view-gem/boards/shields/nice_view_gem/assets/Symbols_Bold_26.c
```

Expected output should show the font header comment with `Size: 26 px`.

- [ ] **Step 3: Commit**

```bash
git add modules/nice-view-gem/boards/shields/nice_view_gem/assets/Symbols_Bold_26.c
git commit -m "feat: copy symbol font from prospector for modifier widget"
```

---

## Task 2: Create `widgets/modifiers.h`

**Files:**
- Create: `modules/nice-view-gem/boards/shields/nice_view_gem/widgets/modifiers.h`

- [ ] **Step 1: Create the header**

```c
// modules/nice-view-gem/boards/shields/nice_view_gem/widgets/modifiers.h
#pragma once
#include <lvgl.h>
#include "util.h"

void draw_modifier_status(lv_obj_t *canvas, const struct status_state *state);
```

- [ ] **Step 2: Commit**

```bash
git add modules/nice-view-gem/boards/shields/nice_view_gem/widgets/modifiers.h
git commit -m "feat: add modifiers.h header"
```

---

## Task 3: Create `widgets/modifiers.c`

**Files:**
- Create: `modules/nice-view-gem/boards/shields/nice_view_gem/widgets/modifiers.c`

Symbol codepoints (same as prospector's `symbols.h`):
- `SYMBOL_COMMAND  "\xF4\x80\x86\x94"` — ⌘
- `SYMBOL_OPTION   "\xF4\x80\x86\x95"` — ⌥
- `SYMBOL_CONTROL  "\xF4\x80\x86\x8D"` — ⌃
- `SYMBOL_SHIFT    "\xF4\x80\x86\x9D"` — ⇧ outline
- `SYMBOL_SHIFT_FILLED "\xF4\x80\x86\x9E"` — ⇧ filled (Caps Word)

Layout (pre-rotation coordinates in 68x68 canvas):
- Row 0 y=2:  ⇧ → `mods[3]` (SHIFT)
- Row 1 y=18: ⌃ → `mods[2]` (CTRL)
- Row 2 y=34: ⌥ → `mods[1]` (ALT)
- Row 3 y=50: ⌘ → `mods[0]` (GUI)

Each row is 16px tall. Active = filled foreground rect + inverted symbol. Inactive = foreground symbol only.

- [ ] **Step 1: Create modifiers.c**

```c
// modules/nice-view-gem/boards/shields/nice_view_gem/widgets/modifiers.c
#include <zephyr/kernel.h>
#include "modifiers.h"

/* Symbol codepoints matching prospector's symbols.h */
#define SYMBOL_COMMAND      "\xF4\x80\x86\x94"
#define SYMBOL_OPTION       "\xF4\x80\x86\x95"
#define SYMBOL_CONTROL      "\xF4\x80\x86\x8D"
#define SYMBOL_SHIFT        "\xF4\x80\x86\x9D"
#define SYMBOL_SHIFT_FILLED "\xF4\x80\x86\x9E"

LV_FONT_DECLARE(Symbols_Bold_26);

static const struct {
    int mod_idx;
    const char *symbol;
} mod_rows[4] = {
    {3, SYMBOL_SHIFT},   /* row 0: SHIFT */
    {2, SYMBOL_CONTROL}, /* row 1: CTRL  */
    {1, SYMBOL_OPTION},  /* row 2: ALT   */
    {0, SYMBOL_COMMAND}, /* row 3: GUI   */
};

void draw_modifier_status(lv_obj_t *canvas, const struct status_state *state) {
    for (int i = 0; i < 4; i++) {
        int y = 2 + i * 16;
        bool active = state->mods[mod_rows[i].mod_idx];
        const char *sym = mod_rows[i].symbol;

        /* Caps Word: show filled shift and treat as active */
        if (i == 0 && state->caps_word) {
            sym = SYMBOL_SHIFT_FILLED;
            active = true;
        }

        if (active) {
            lv_draw_rect_dsc_t rect_dsc;
            init_rect_dsc(&rect_dsc, LVGL_FOREGROUND);
            canvas_draw_rect(canvas, 0, y, 68, 16, &rect_dsc);

            lv_draw_label_dsc_t label_dsc;
            init_label_dsc(&label_dsc, LVGL_BACKGROUND, &Symbols_Bold_26, LV_TEXT_ALIGN_CENTER);
            canvas_draw_text(canvas, 0, y, 68, &label_dsc, sym);
        } else {
            lv_draw_label_dsc_t label_dsc;
            init_label_dsc(&label_dsc, LVGL_FOREGROUND, &Symbols_Bold_26, LV_TEXT_ALIGN_CENTER);
            canvas_draw_text(canvas, 0, y, 68, &label_dsc, sym);
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/nice-view-gem/boards/shields/nice_view_gem/widgets/modifiers.c
git commit -m "feat: add draw_modifier_status() canvas implementation"
```

---

## Task 4: Add modifier state fields to `util.h`

**Files:**
- Modify: `modules/nice-view-gem/boards/shields/nice_view_gem/widgets/util.h:34`

Current central-only block (lines 33-37):
```c
    uint8_t layer_index;
    const char *layer_label;
    uint8_t wpm[10];
```

- [ ] **Step 1: Add mods and caps_word fields after wpm[10]**

New central-only block:
```c
    uint8_t layer_index;
    const char *layer_label;
    uint8_t wpm[10];
    bool mods[4];    /* GUI=0, ALT=1, CTRL=2, SHIFT=3 */
    bool caps_word;
```

- [ ] **Step 2: Verify the file compiles (do a quick syntax check)**

```bash
grep -A 8 "uint8_t wpm" modules/nice-view-gem/boards/shields/nice_view_gem/widgets/util.h
```

Expected: shows `bool mods[4]` and `bool caps_word` after `wpm[10]`.

- [ ] **Step 3: Commit**

```bash
git add modules/nice-view-gem/boards/shields/nice_view_gem/widgets/util.h
git commit -m "feat: add modifier state fields to status_state"
```

---

## Task 5: Update `screen.c` for conditional modifier support

**Files:**
- Modify: `modules/nice-view-gem/boards/shields/nice_view_gem/widgets/screen.c`

Current state (reference):
- Line 12: `#include <zmk/events/wpm_state_changed.h>`
- Line 19: `#include <zmk/wpm.h>`
- Line 26: `#include "wpm.h"`
- Lines 46-55: `draw_middle()` calls `draw_wpm_status()`
- Lines 173-197: WPM subscription block
- Line 225: `widget_wpm_status_init()`

- [ ] **Step 1: Replace the wpm includes (lines 12, 19, 26) with conditional block**

Remove:
```c
#include <zmk/events/wpm_state_changed.h>
```
and
```c
#include <zmk/wpm.h>
```
and
```c
#include "wpm.h"
```

Add after the existing includes block (after line 26 `#include "wpm.h"`):
```c
#if IS_ENABLED(CONFIG_NICE_VIEW_GEM_MODIFIERS)
#include <zmk/events/keycode_state_changed.h>
#include <zmk/hid.h>
#include <dt-bindings/zmk/hid_usage.h>
#include <dt-bindings/zmk/hid_usage_pages.h>
#ifdef CONFIG_DT_HAS_ZMK_BEHAVIOR_CAPS_WORD_ENABLED
#include <zmk/events/caps_word_state_changed.h>
#endif
#include "modifiers.h"
#else
#include <zmk/events/wpm_state_changed.h>
#include <zmk/wpm.h>
#include "wpm.h"
#endif
```

- [ ] **Step 2: Update `draw_middle()` (lines 46-55)**

Replace:
```c
static void draw_middle(lv_obj_t *widget, const struct status_state *state) {
    lv_obj_t *canvas = lv_obj_get_child(widget, 1);
    fill_background(canvas);

    // Draw widgets
    draw_wpm_status(canvas, state);

    // Rotate for horizontal display
    rotate_canvas(canvas);
}
```

With:
```c
static void draw_middle(lv_obj_t *widget, const struct status_state *state) {
    lv_obj_t *canvas = lv_obj_get_child(widget, 1);
    fill_background(canvas);

#if IS_ENABLED(CONFIG_NICE_VIEW_GEM_MODIFIERS)
    draw_modifier_status(canvas, state);
#else
    draw_wpm_status(canvas, state);
#endif

    rotate_canvas(canvas);
}
```

- [ ] **Step 3: Replace the WPM status section (lines 173-197) with conditional block**

Replace the entire WPM status section:
```c
/**
 * WPM status
 **/

static void set_wpm_status(struct zmk_widget_screen *widget, struct wpm_status_state state) {
    for (int i = 0; i < 9; i++) {
        widget->state.wpm[i] = widget->state.wpm[i + 1];
    }
    widget->state.wpm[9] = state.wpm;

    draw_middle(widget->obj, &widget->state);
}

static void wpm_status_update_cb(struct wpm_status_state state) {
    struct zmk_widget_screen *widget;
    SYS_SLIST_FOR_EACH_CONTAINER(&widgets, widget, node) { set_wpm_status(widget, state); }
}

struct wpm_status_state wpm_status_get_state(const zmk_event_t *eh) {
    return (struct wpm_status_state){.wpm = zmk_wpm_get_state()};
};

ZMK_DISPLAY_WIDGET_LISTENER(widget_wpm_status, struct wpm_status_state, wpm_status_update_cb,
                            wpm_status_get_state)
ZMK_SUBSCRIPTION(widget_wpm_status, zmk_wpm_state_changed);
```

With:
```c
#if IS_ENABLED(CONFIG_NICE_VIEW_GEM_MODIFIERS)
/**
 * Modifier status
 **/

struct modifier_status_state {
    bool mods[4];
    bool caps_word;
};

#ifdef CONFIG_DT_HAS_ZMK_BEHAVIOR_CAPS_WORD_ENABLED
static bool caps_word_active = false;
#endif

static void set_modifier_status(struct zmk_widget_screen *widget,
                                struct modifier_status_state state) {
    for (int i = 0; i < 4; i++) {
        widget->state.mods[i] = state.mods[i];
    }
#ifdef CONFIG_DT_HAS_ZMK_BEHAVIOR_CAPS_WORD_ENABLED
    widget->state.caps_word = state.caps_word;
#endif
    draw_middle(widget->obj, &widget->state);
}

static void modifier_status_update_cb(struct modifier_status_state state) {
    struct zmk_widget_screen *widget;
    SYS_SLIST_FOR_EACH_CONTAINER(&widgets, widget, node) { set_modifier_status(widget, state); }
}

static struct modifier_status_state modifier_status_get_state(const zmk_event_t *eh) {
#ifdef CONFIG_DT_HAS_ZMK_BEHAVIOR_CAPS_WORD_ENABLED
    if (eh != NULL) {
        const struct zmk_caps_word_state_changed *ev = as_zmk_caps_word_state_changed(eh);
        if (ev != NULL) {
            caps_word_active = ev->active;
        }
    }
#endif

    struct modifier_status_state state = {
        .mods = {false, false, false, false},
#ifdef CONFIG_DT_HAS_ZMK_BEHAVIOR_CAPS_WORD_ENABLED
        .caps_word = caps_word_active,
#endif
    };

    zmk_mod_flags_t mods = zmk_hid_get_explicit_mods();
    state.mods[0] = (mods & (MOD_LGUI | MOD_RGUI)) != 0;
    state.mods[1] = (mods & (MOD_LALT | MOD_RALT)) != 0;
    state.mods[2] = (mods & (MOD_LCTL | MOD_RCTL)) != 0;
    state.mods[3] = (mods & (MOD_LSFT | MOD_RSFT)) != 0;
    return state;
}

ZMK_DISPLAY_WIDGET_LISTENER(widget_modifier_status, struct modifier_status_state,
                            modifier_status_update_cb, modifier_status_get_state)
ZMK_SUBSCRIPTION(widget_modifier_status, zmk_keycode_state_changed);
#ifdef CONFIG_DT_HAS_ZMK_BEHAVIOR_CAPS_WORD_ENABLED
ZMK_SUBSCRIPTION(widget_modifier_status, zmk_caps_word_state_changed);
#endif

#else
/**
 * WPM status
 **/

static void set_wpm_status(struct zmk_widget_screen *widget, struct wpm_status_state state) {
    for (int i = 0; i < 9; i++) {
        widget->state.wpm[i] = widget->state.wpm[i + 1];
    }
    widget->state.wpm[9] = state.wpm;

    draw_middle(widget->obj, &widget->state);
}

static void wpm_status_update_cb(struct wpm_status_state state) {
    struct zmk_widget_screen *widget;
    SYS_SLIST_FOR_EACH_CONTAINER(&widgets, widget, node) { set_wpm_status(widget, state); }
}

struct wpm_status_state wpm_status_get_state(const zmk_event_t *eh) {
    return (struct wpm_status_state){.wpm = zmk_wpm_get_state()};
};

ZMK_DISPLAY_WIDGET_LISTENER(widget_wpm_status, struct wpm_status_state, wpm_status_update_cb,
                            wpm_status_get_state)
ZMK_SUBSCRIPTION(widget_wpm_status, zmk_wpm_state_changed);
#endif
```

- [ ] **Step 4: Update init call (line 225)**

Replace:
```c
    widget_wpm_status_init();
```

With:
```c
#if IS_ENABLED(CONFIG_NICE_VIEW_GEM_MODIFIERS)
    widget_modifier_status_init();
#else
    widget_wpm_status_init();
#endif
```

- [ ] **Step 5: Commit**

```bash
git add modules/nice-view-gem/boards/shields/nice_view_gem/widgets/screen.c
git commit -m "feat: add conditional modifier subscription in screen.c"
```

---

## Task 6: Update `CMakeLists.txt`

**Files:**
- Modify: `modules/nice-view-gem/boards/shields/nice_view_gem/CMakeLists.txt:13`

- [ ] **Step 1: Replace unconditional wpm.c with conditional block**

Replace:
```cmake
  zephyr_library_sources(widgets/wpm.c)
```

With:
```cmake
  if(CONFIG_NICE_VIEW_GEM_MODIFIERS)
    zephyr_library_sources(assets/Symbols_Bold_26.c)
    zephyr_library_sources(widgets/modifiers.c)
  else()
    zephyr_library_sources(widgets/wpm.c)
  endif()
```

- [ ] **Step 2: Commit**

```bash
git add modules/nice-view-gem/boards/shields/nice_view_gem/CMakeLists.txt
git commit -m "feat: conditional modifiers.c vs wpm.c in CMakeLists"
```

---

## Task 7: Update `Kconfig.defconfig`

**Files:**
- Modify: `modules/nice-view-gem/boards/shields/nice_view_gem/Kconfig.defconfig`

- [ ] **Step 1: Add NICE_VIEW_GEM_MODIFIERS option**

After the animation configs (before `config NICE_VIEW_WIDGET_STATUS` around line 50), add:
```kconfig
config NICE_VIEW_GEM_MODIFIERS
    bool "Show modifier indicators instead of WPM on middle canvas"
    default n
```

- [ ] **Step 2: Make ZMK_WPM conditional**

Replace the central-only block (lines 60-65):
```kconfig
if !ZMK_SPLIT || ZMK_SPLIT_ROLE_CENTRAL

config NICE_VIEW_WIDGET_STATUS
    select ZMK_WPM

endif # !ZMK_SPLIT || ZMK_SPLIT_ROLE_CENTRAL
```

With:
```kconfig
if !ZMK_SPLIT || ZMK_SPLIT_ROLE_CENTRAL

config NICE_VIEW_WIDGET_STATUS
    select ZMK_WPM if !NICE_VIEW_GEM_MODIFIERS

endif # !ZMK_SPLIT || ZMK_SPLIT_ROLE_CENTRAL
```

- [ ] **Step 3: Commit**

```bash
git add modules/nice-view-gem/boards/shields/nice_view_gem/Kconfig.defconfig
git commit -m "feat: add NICE_VIEW_GEM_MODIFIERS Kconfig option"
```

---

## Task 8: Build verification

- [ ] **Step 1: Build with WPM (default — no conf change)**

```bash
make hsv/left 2>&1 | grep -E "(Wrote|FAILED|error:|warning:|Memory region)"
```

Expected: `Wrote` line with `.uf2` path. No errors.

- [ ] **Step 2: Enable modifiers and rebuild**

```bash
echo "CONFIG_NICE_VIEW_GEM_MODIFIERS=y" >> config/hillside_view.conf
make hsv/left 2>&1 | grep -E "(Wrote|FAILED|error:|warning:|Memory region)"
```

Expected: `Wrote` line. No errors. No `ZMK_WPM` being selected.

- [ ] **Step 3: Check WPM is not selected when modifiers enabled**

```bash
grep -r "ZMK_WPM" modules/nice-view-gem/boards/shields/nice_view_gem/
```

Expected: only appears in Kconfig.defconfig with `if !NICE_VIEW_GEM_MODIFIERS` guard.

- [ ] **Step 4: Restore default and verify WPM still works**

```bash
# Remove the last line added to hillside_view.conf
sed -i '/CONFIG_NICE_VIEW_GEM_MODIFIERS=y/d' config/hillside_view.conf
make hsv/left 2>&1 | grep -E "(Wrote|FAILED|error:|warning:|Memory region)"
```

Expected: `Wrote` line. WPM build succeeds.

- [ ] **Step 5: Commit verification results note + any fixups**

```bash
git add -p  # stage only fixup changes if any
git commit -m "fix: build verification fixups for modifier widget"
```
