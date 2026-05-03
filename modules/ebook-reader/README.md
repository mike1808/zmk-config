# ebook-reader ZMK Module

A ZMK shield module that turns the Hillside View nice!view display into an e-ink book reader.

## Display layout

```
┌──────────────────────────────────────────────────────────────────┐ y=0
│                                                                  │
│  Text (pixel_operator_mono, 20 chars × 4 lines)                 │
│                                                                  │
├────────────────────────────────────────────────────────┬─────────┤ y=60
│  Progress bar (4px pad, 124px wide)                    │  "42"   │ 8px
└────────────────────────────────────────────────────────┴─────────┘ y=68
```

## Navigation

- `J + K` combo — next page
- `F + G` combo — previous page

Combos are defined in `ebook_reader.overlay` and only apply to ebook builds.

> **TODO:** Behaviors/combos live in the overlay instead of `hillside_view.keymap` because
> `CONFIG_*` Kconfig macros are unavailable to the DTS preprocessor for keymap files in user
> config dirs. Proper fix: dedicated `hillside_view_ebook.keymap` or pass autoconf.h to
> the DTS preprocessor.

## Adding a book

1. Get a plain-text `.txt` from [Project Gutenberg](https://www.gutenberg.org/)
2. Place it in `modules/ebook-reader/books/`
3. Run paginate.py:

```bash
python3 modules/ebook-reader/tools/paginate.py \
  --input modules/ebook-reader/books/<book>.txt \
  --output modules/ebook-reader/boards/shields/ebook_reader/ebook_data.c
```

Default layout: 20 chars/line, 4 lines/page (matches `pixel_operator_mono` at 160×60px).
Override with `--chars-per-line` and `--lines-per-page`.

`ebook_data.c` is gitignored — regenerate after cloning.

## Building

```bash
make ebook/left ZMK_ROOT=~/path/to/zmk
make ebook/upload/left
```

## Module structure

```
modules/ebook-reader/
  zephyr/module.yml                        # Zephyr module declaration
  dts/bindings/behaviors/
    zmk,behavior-ebook-nav.yaml            # DT binding for nav behavior
  boards/shields/ebook_reader/
    Kconfig.shield / Kconfig.defconfig     # Shield + display config
    ebook_reader.conf                      # CONFIG_ZMK_DISPLAY=y etc.
    ebook_reader.overlay                   # Nav behaviors + combos
    CMakeLists.txt
    custom_status_screen.c                 # LVGL display implementation
    behaviors/behavior_ebook_nav.c         # Page nav behavior driver
    events/ebook_page_changed.[ch]         # Custom ZMK event
    ebook_data.h                           # extern pages[] declaration
    ebook_data.c                           # Generated — gitignored
    assets/pixel_operator_mono.c           # Font (copied from nice-view-gem)
  tools/
    paginate.py                            # txt → ebook_data.c
  books/
    metamorphosis.txt                      # The Metamorphosis, Kafka (PD)
```
