# Nice-View-Gem Widget Implementation Guide

Reference for implementing new display widgets in the nice-view-gem ZMK module.

Module root: `modules/nice-view-gem/boards/shields/nice_view_gem/`

## Architecture Overview

The display is a 160x68 Nice!View e-paper screen, split into three 68x68 canvases drawn in pre-rotation coordinates then rotated 270 degrees for physical display orientation.

```
Screen (160h x 68w, rotated)
├── Top canvas    (child 0, offset 0):     Battery + Output status
├── Middle canvas (child 1, offset -44):   WPM gauge OR Modifier indicators
└── Bottom canvas (child 2, offset -112):  Profile dots + Layer name
```

Each canvas uses `LV_COLOR_FORMAT_L8` (8-bit grayscale). Drawing happens in a 68x68 pre-rotation coordinate space, then `rotate_canvas()` handles the 270-degree rotation.

## File Structure

For each widget, create two files:

```
widgets/
├── my_widget.h     # Function declaration
├── my_widget.c     # Drawing implementation
├── screen.c        # Integration: event subscription, draw dispatch, init
├── util.h          # Shared constants, status_state struct, helpers
└── util.c          # Helper function implementations
```

### Header Pattern (`my_widget.h`)

```c
#pragma once

#include <lvgl.h>
#include "util.h"

void draw_my_widget(lv_obj_t *canvas, const struct status_state *state);
```

### Implementation Pattern (`my_widget.c`)

```c
#include <zephyr/kernel.h>
#include "my_widget.h"

// If using custom fonts:
LV_FONT_DECLARE(font_name);

void draw_my_widget(lv_obj_t *canvas, const struct status_state *state) {
    // Use canvas_draw_* helpers from util.h
}
```

## Drawing API (from `util.h` / `util.c`)

### Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `CANVAS_SIZE` | 68 | Canvas width and height in pixels |
| `LVGL_FOREGROUND` | black (or white if inverted) | Primary draw color |
| `LVGL_BACKGROUND` | white (or black if inverted) | Background color |

### Drawing Functions

```c
// Fill canvas with background color
void fill_background(lv_obj_t *canvas);

// Rotate canvas 270 degrees for physical display orientation
void rotate_canvas(lv_obj_t *canvas);

// Initialize drawing descriptors
void init_rect_dsc(lv_draw_rect_dsc_t *rect_dsc, lv_color_t bg_color);
void init_line_dsc(lv_draw_line_dsc_t *line_dsc, lv_color_t color, uint8_t width);
void init_label_dsc(lv_draw_label_dsc_t *label_dsc, lv_color_t color,
                    const lv_font_t *font, lv_text_align_t align);

// Canvas draw primitives
void canvas_draw_rect(lv_obj_t *canvas, int32_t x, int32_t y,
                      int32_t w, int32_t h, lv_draw_rect_dsc_t *rect_dsc);
void canvas_draw_text(lv_obj_t *canvas, int32_t x, int32_t y,
                      int32_t max_w, lv_draw_label_dsc_t *label_dsc, const char *text);
void canvas_draw_line(lv_obj_t *canvas, const lv_point_t *points,
                      uint32_t point_cnt, lv_draw_line_dsc_t *line_dsc);
void canvas_draw_img(lv_obj_t *canvas, int32_t x, int32_t y,
                     const void *src, lv_draw_image_dsc_t *img_dsc);

// String utility
void to_uppercase(char *str);
```

### Drawing Pattern

```c
void draw_my_widget(lv_obj_t *canvas, const struct status_state *state) {
    // 1. Filled rectangle (e.g., highlight background)
    lv_draw_rect_dsc_t rect_dsc;
    init_rect_dsc(&rect_dsc, LVGL_FOREGROUND);
    canvas_draw_rect(canvas, x, y, width, height, &rect_dsc);

    // 2. Text label
    lv_draw_label_dsc_t label_dsc;
    init_label_dsc(&label_dsc, LVGL_FOREGROUND, &pixel_operator_mono, LV_TEXT_ALIGN_CENTER);
    canvas_draw_text(canvas, x, y, max_width, &label_dsc, "TEXT");

    // 3. Inverted text (text on filled rect)
    init_label_dsc(&label_dsc, LVGL_BACKGROUND, &font, LV_TEXT_ALIGN_CENTER);
    canvas_draw_text(canvas, x, y, max_width, &label_dsc, "INVERTED");
}
```

## Event Subscription Pipeline

The flow: **ZMK Event -> get_state() -> update_cb() -> set_status() -> draw()**

### In `screen.c`: Full Subscription Pattern

```c
/** My Widget Status **/

// 1. Local state struct (what this listener extracts)
struct my_widget_status_state {
    int value;
    bool flag;
};

// 2. Set function: copies local state into global status_state, triggers redraw
static void set_my_widget_status(struct zmk_widget_screen *widget,
                                  struct my_widget_status_state state) {
    widget->state.my_field = state.value;
    draw_middle(widget->obj, &widget->state);  // or draw_top / draw_bottom
}

// 3. Update callback: iterates all widget instances
static void my_widget_status_update_cb(struct my_widget_status_state state) {
    struct zmk_widget_screen *widget;
    SYS_SLIST_FOR_EACH_CONTAINER(&widgets, widget, node) {
        set_my_widget_status(widget, state);
    }
}

// 4. State getter: extracts current state from ZMK (called with event or NULL on init)
static struct my_widget_status_state my_widget_status_get_state(const zmk_event_t *eh) {
    return (struct my_widget_status_state){
        .value = zmk_some_api_get_value(),
        .flag = zmk_some_api_get_flag(),
    };
}

// 5. Register listener + subscribe to events
ZMK_DISPLAY_WIDGET_LISTENER(widget_my_widget_status, struct my_widget_status_state,
                            my_widget_status_update_cb, my_widget_status_get_state)
ZMK_SUBSCRIPTION(widget_my_widget_status, zmk_relevant_event_changed);
```

### Init Registration

In `zmk_widget_screen_init()`:

```c
widget_my_widget_status_init();
```

### Draw Dispatch

In the appropriate draw function (`draw_top`, `draw_middle`, or `draw_bottom`):

```c
static void draw_middle(lv_obj_t *widget, const struct status_state *state) {
    lv_obj_t *canvas = lv_obj_get_child(widget, 1);  // 0=top, 1=middle, 2=bottom
    fill_background(canvas);
    draw_my_widget(canvas, state);
    rotate_canvas(canvas);
}
```

## `status_state` Struct (`util.h`)

The unified state struct passed to all draw functions:

```c
struct status_state {
    // Shared (all builds)
    uint8_t battery;
    bool charging;

#if !IS_ENABLED(CONFIG_ZMK_SPLIT) || IS_ENABLED(CONFIG_ZMK_SPLIT_ROLE_CENTRAL)
    // Central-only fields
    struct zmk_endpoint_instance selected_endpoint;
    int active_profile_index;
    bool active_profile_connected;
    bool active_profile_bonded;
    uint8_t layer_index;
    const char *layer_label;
    uint8_t wpm[10];
    bool mods[4];       // GUI=0, ALT=1, CTRL=2, SHIFT=3
    bool caps_word;
#else
    // Peripheral-only
    bool connected;
#endif
};
```

Add new fields to the appropriate section. Central-only fields are only available on the connected/central side of split keyboards.

## CMakeLists.txt Integration

```cmake
# Inside the central-only block:
if(NOT CONFIG_ZMK_SPLIT OR CONFIG_ZMK_SPLIT_ROLE_CENTRAL)
    # Unconditional widget sources
    zephyr_library_sources(widgets/layer.c)

    # Conditional widget (mutually exclusive)
    if(CONFIG_MY_WIDGET_OPTION)
        zephyr_library_sources(widgets/my_widget.c)
        zephyr_library_sources(assets/my_font.c)  # if needed
    else()
        zephyr_library_sources(widgets/default_widget.c)
    endif()
endif()
```

## Kconfig.defconfig Integration

```kconfig
# User-visible option (in shared section, outside split guard)
config NICE_VIEW_GEM_MY_FEATURE
    bool "Description of feature"
    default n

# Conditional dependency (inside split guard)
if !ZMK_SPLIT || ZMK_SPLIT_ROLE_CENTRAL

config NICE_VIEW_WIDGET_STATUS
    select ZMK_DEPENDENCY if !NICE_VIEW_GEM_MY_FEATURE

endif
```

## Available Assets

### Fonts

| Font | Size | Format | Use |
|------|------|--------|-----|
| `pixel_operator_mono` | 16px | 1-bpp | Text labels (declared in `assets/custom_fonts.h`) |
| `Symbols_Bold_26` | 26px | 4-bpp | Mac modifier symbols ⇧⌃⌥⌘ |

Font usage: `LV_FONT_DECLARE(font_name);` then pass `&font_name` to `init_label_dsc()`.

### Images

Declared in `assets/images.c` with `LV_IMG_DECLARE(name)`:

| Image | Size | Purpose |
|-------|------|---------|
| `bolt` | 5x9 | Charging indicator |
| `bt` | 12x11 | Bluetooth connected |
| `bt_no_signal` | - | Bluetooth disconnected |
| `bt_unbonded` | - | Bluetooth unpaired |
| `usb` | - | USB connected |
| `gauge` | - | WPM gauge background |
| `grid` | - | WPM graph grid |
| `profiles` | - | Profile dots background |

All images use `LV_COLOR_FORMAT_I1` (1-bit indexed) with color palettes that respect `CONFIG_NICE_VIEW_WIDGET_INVERTED`.

## Common ZMK Events for Subscription

| Event | Header | Use |
|-------|--------|-----|
| `zmk_battery_state_changed` | `zmk/events/battery_state_changed.h` | Battery level updates |
| `zmk_usb_conn_state_changed` | `zmk/events/usb_conn_state_changed.h` | USB plug/unplug |
| `zmk_ble_active_profile_changed` | `zmk/events/ble_active_profile_changed.h` | BLE profile switch |
| `zmk_endpoint_changed` | `zmk/events/endpoint_changed.h` | Output endpoint change |
| `zmk_layer_state_changed` | `zmk/events/layer_state_changed.h` | Layer activation |
| `zmk_keycode_state_changed` | `zmk/events/keycode_state_changed.h` | Key press/release |
| `zmk_wpm_state_changed` | `zmk/events/wpm_state_changed.h` | WPM counter update |
| `zmk_split_peripheral_status_changed` | `zmk/events/split_peripheral_status_changed.h` | Peripheral connect/disconnect |

## Behavior Override Pattern

When ZMK doesn't raise an event you need (e.g., caps_word state change), you can override the behavior to add event emission.

**Key insight:** ZMK core does NOT raise `zmk_caps_word_state_changed` — that event is a custom addition. The stock `behavior_caps_word.c` tracks state privately with no public API.

### Steps

1. **Create event header** (if ZMK doesn't have one): define the event struct
2. **Create event impl**: `events/my_event.c` with `ZMK_EVENT_IMPL(zmk_my_event)`
3. **Create behavior override**: `behaviors/behavior_name.c` — copy ZMK's behavior, add `raise_zmk_my_event()` calls
4. **CMakeLists.txt**:
   ```cmake
   # Provide event implementation
   zephyr_library_sources(events/my_event.c)

   # Suppress ZMK's original behavior
   set_source_files_properties(
       ${APPLICATION_SOURCE_DIR}/src/behaviors/behavior_name.c
       TARGET_DIRECTORY app
       PROPERTIES HEADER_FILE_ONLY ON)

   # Compile our replacement into the app target
   target_sources(app PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/behaviors/behavior_name.c)
   ```

**Guard with `!CONFIG_SHIELD_PROSPECTOR_ADAPTER`** if prospector already provides the same override, to avoid duplicate symbols.

## Checklist for New Widget

1. Add state fields to `status_state` in `util.h` (in correct section)
2. Create `widgets/my_widget.h` with draw function declaration
3. Create `widgets/my_widget.c` with draw implementation
4. In `screen.c`: add includes, local state struct, set/update/get_state functions, `ZMK_DISPLAY_WIDGET_LISTENER`, `ZMK_SUBSCRIPTION`, init call, draw dispatch
5. In `CMakeLists.txt`: add source files (conditionally if needed)
6. In `Kconfig.defconfig`: add config option if feature is toggleable
7. Build test: `make hsv/left` with feature on and off
