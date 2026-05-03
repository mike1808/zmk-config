#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <lvgl.h>

#include <zmk/display.h>
#include <zmk/event_manager.h>

#include "ebook_data.h"
#include "events/ebook_page_changed.h"

LOG_MODULE_DECLARE(zmk, CONFIG_ZMK_LOG_LEVEL);

/* pixel_operator_mono: line_height=13px, char_width=8px
 * 160px wide / 8px = 20 chars per line
 * 60px tall  / 13px = ~4 lines per page (52px used)
 */

LV_FONT_DECLARE(pixel_operator_mono);

static lv_obj_t *text_label;
static lv_obj_t *page_num_label;
static lv_obj_t *progress_bar;

lv_obj_t *zmk_display_status_screen() {
    lv_obj_t *screen = lv_obj_create(NULL);
    lv_obj_set_style_bg_color(screen, lv_color_white(), LV_PART_MAIN);
    lv_obj_set_style_bg_opa(screen, LV_OPA_COVER, LV_PART_MAIN);
    lv_obj_set_style_pad_all(screen, 0, LV_PART_MAIN);
    lv_obj_set_style_border_width(screen, 0, LV_PART_MAIN);

    /* Text area: 160x60px, top-left corner */
    text_label = lv_label_create(screen);
    lv_obj_set_pos(text_label, 0, 0);
    lv_obj_set_size(text_label, 160, 60);
    lv_label_set_long_mode(text_label, LV_LABEL_LONG_CLIP);
    lv_obj_set_style_text_font(text_label, &pixel_operator_mono, LV_PART_MAIN);
    lv_obj_set_style_text_color(text_label, lv_color_black(), LV_PART_MAIN);
    lv_obj_set_style_pad_all(text_label, 0, LV_PART_MAIN);
    lv_label_set_text(text_label, ebook_pages[0]);

    /* Progress bar: x=4, y=60, w=124, h=8 (4px left pad, 4px gap before page num) */
    progress_bar = lv_bar_create(screen);
    lv_obj_set_pos(progress_bar, 4, 60);
    lv_obj_set_size(progress_bar, 124, 8);
    lv_bar_set_range(progress_bar, 0, 100);
    lv_bar_set_value(progress_bar, 0, LV_ANIM_OFF);
    lv_obj_set_style_bg_color(progress_bar, lv_color_black(), LV_PART_INDICATOR);
    lv_obj_set_style_bg_color(progress_bar, lv_color_white(), LV_PART_MAIN);
    lv_obj_set_style_border_color(progress_bar, lv_color_black(), LV_PART_MAIN);
    lv_obj_set_style_border_width(progress_bar, 1, LV_PART_MAIN);
    lv_obj_set_style_pad_all(progress_bar, 0, LV_PART_MAIN);
    lv_obj_set_style_radius(progress_bar, 0, LV_PART_MAIN);
    lv_obj_set_style_radius(progress_bar, 0, LV_PART_INDICATOR);

    /* Page number: x=132, y=60, w=24, h=8, right-aligned (4px right pad) */
    page_num_label = lv_label_create(screen);
    lv_obj_set_pos(page_num_label, 132, 60);
    lv_obj_set_size(page_num_label, 24, 8);
    lv_obj_set_style_text_font(page_num_label, &pixel_operator_mono, LV_PART_MAIN);
    lv_obj_set_style_text_color(page_num_label, lv_color_black(), LV_PART_MAIN);
    lv_obj_set_style_text_align(page_num_label, LV_TEXT_ALIGN_RIGHT, LV_PART_MAIN);
    lv_obj_set_style_pad_all(page_num_label, 0, LV_PART_MAIN);
    lv_label_set_text_fmt(page_num_label, "%d", 1);

    return screen;
}

struct ebook_page_state {
    uint16_t page_idx;
};

static void set_ebook_page(struct ebook_page_state state) {
    uint16_t idx = state.page_idx;

    lv_label_set_text(text_label, ebook_pages[idx]);

    int progress = (ebook_total_pages > 1)
        ? (idx * 100 / (ebook_total_pages - 1))
        : 100;
    lv_bar_set_value(progress_bar, progress, LV_ANIM_OFF);

    lv_label_set_text_fmt(page_num_label, "%d", idx + 1);
}

static struct ebook_page_state ebook_page_get_state(const zmk_event_t *eh) {
    const struct zmk_ebook_page_changed *ev = as_zmk_ebook_page_changed(eh);
    return (struct ebook_page_state){
        .page_idx = (ev != NULL) ? ev->page_idx : 0,
    };
}

ZMK_DISPLAY_WIDGET_LISTENER(widget_ebook_page, struct ebook_page_state, set_ebook_page,
                             ebook_page_get_state)
ZMK_SUBSCRIPTION(widget_ebook_page, zmk_ebook_page_changed);
