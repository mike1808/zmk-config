#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <lvgl.h>

#include <zmk/display.h>
#include <zmk/event_manager.h>

#include "ebook_data.h"
#include "events/ebook_page_changed.h"

extern uint16_t ebook_current_page;

LOG_MODULE_DECLARE(zmk, CONFIG_ZMK_LOG_LEVEL);

/* pixel_operator_mono: line_height=13px, char_width=8px
 * 160px wide / 8px = 20 chars per line
 * 60px tall  / 13px = ~4 lines per page (52px used)
 *
 * Smooth scroll: two labels in a clipped 160x60 container.
 * On page change, both slide simultaneously (ease-in-out, 150ms).
 * Next page: current 0→-60, incoming +60→0.
 * Prev page: current 0→+60, incoming -60→0.
 */

#define SCROLL_ANIM_MS 150
#define TEXT_H         60

LV_FONT_DECLARE(pixel_operator_mono);

static lv_obj_t *text_container;
static lv_obj_t *text_labels[2];
static int       active_label = 0;
static uint16_t  displayed_page = 0;

static lv_obj_t *page_num_label;
static lv_obj_t *progress_bar;

static void label_set_y_cb(void *obj, int32_t y) {
    lv_obj_set_y((lv_obj_t *)obj, y);
}

static lv_obj_t *make_text_label(lv_obj_t *parent) {
    lv_obj_t *label = lv_label_create(parent);
    lv_obj_set_size(label, 160, TEXT_H);
    lv_label_set_long_mode(label, LV_LABEL_LONG_CLIP);
    lv_obj_set_style_text_font(label, &pixel_operator_mono, LV_PART_MAIN);
    lv_obj_set_style_text_color(label, lv_color_black(), LV_PART_MAIN);
    lv_obj_set_style_pad_all(label, 0, LV_PART_MAIN);
    return label;
}

lv_obj_t *zmk_display_status_screen() {
    lv_obj_t *screen = lv_obj_create(NULL);
    lv_obj_set_style_bg_color(screen, lv_color_white(), LV_PART_MAIN);
    lv_obj_set_style_bg_opa(screen, LV_OPA_COVER, LV_PART_MAIN);
    lv_obj_set_style_pad_all(screen, 0, LV_PART_MAIN);
    lv_obj_set_style_border_width(screen, 0, LV_PART_MAIN);

    /* Clipped container for scroll animation */
    text_container = lv_obj_create(screen);
    lv_obj_set_pos(text_container, 0, 0);
    lv_obj_set_size(text_container, 160, TEXT_H);
    lv_obj_set_style_bg_opa(text_container, LV_OPA_TRANSP, LV_PART_MAIN);
    lv_obj_set_style_border_width(text_container, 0, LV_PART_MAIN);
    lv_obj_set_style_pad_all(text_container, 0, LV_PART_MAIN);
    lv_obj_set_scrollbar_mode(text_container, LV_SCROLLBAR_MODE_OFF);

    text_labels[0] = make_text_label(text_container);
    text_labels[1] = make_text_label(text_container);
    lv_obj_set_pos(text_labels[0], 0, 0);
    lv_obj_set_pos(text_labels[1], 0, TEXT_H);  /* off-screen initially */
    lv_label_set_text(text_labels[0], ebook_pages[ebook_current_page]);
    lv_label_set_text(text_labels[1], "");
    displayed_page = ebook_current_page;

    /* Progress bar: x=4, y=60, w=124, h=8 (4px left pad, 4px gap before page num) */
    progress_bar = lv_bar_create(screen);
    lv_obj_set_pos(progress_bar, 4, 60);
    lv_obj_set_size(progress_bar, 124, 8);
    lv_bar_set_range(progress_bar, 0, 100);
    int init_progress = (ebook_total_pages > 1)
        ? (ebook_current_page * 100 / (ebook_total_pages - 1))
        : 100;
    lv_bar_set_value(progress_bar, init_progress, LV_ANIM_OFF);
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
    lv_obj_set_style_text_font(page_num_label, &lv_font_unscii_8, LV_PART_MAIN);
    lv_obj_set_style_text_color(page_num_label, lv_color_black(), LV_PART_MAIN);
    lv_obj_set_style_text_align(page_num_label, LV_TEXT_ALIGN_RIGHT, LV_PART_MAIN);
    lv_obj_set_style_pad_all(page_num_label, 0, LV_PART_MAIN);
    lv_label_set_text_fmt(page_num_label, "%d", ebook_current_page + 1);

    return screen;
}

struct ebook_page_state {
    uint16_t page_idx;
};

static void set_ebook_page(struct ebook_page_state state) {
    uint16_t idx = state.page_idx;

    /* Update progress bar and page number immediately */
    int progress = (ebook_total_pages > 1)
        ? (idx * 100 / (ebook_total_pages - 1))
        : 100;
    lv_bar_set_value(progress_bar, progress, LV_ANIM_OFF);
    lv_label_set_text_fmt(page_num_label, "%d", idx + 1);

    bool going_forward = (idx > displayed_page);
    int  incoming_start_y = going_forward ? TEXT_H : -TEXT_H;
    int  outgoing_end_y   = going_forward ? -TEXT_H : TEXT_H;

    int incoming = 1 - active_label;

    /* Position incoming label off-screen and set its text */
    lv_obj_set_y(text_labels[incoming], incoming_start_y);
    lv_label_set_text(text_labels[incoming], ebook_pages[idx]);

    /* Animate outgoing label off-screen */
    lv_anim_t a_out;
    lv_anim_init(&a_out);
    lv_anim_set_exec_cb(&a_out, label_set_y_cb);
    lv_anim_set_var(&a_out, text_labels[active_label]);
    lv_anim_set_values(&a_out, 0, outgoing_end_y);
    lv_anim_set_time(&a_out, SCROLL_ANIM_MS);
    lv_anim_set_path_cb(&a_out, lv_anim_path_ease_in_out);
    lv_anim_start(&a_out);

    /* Animate incoming label to centre */
    lv_anim_t a_in;
    lv_anim_init(&a_in);
    lv_anim_set_exec_cb(&a_in, label_set_y_cb);
    lv_anim_set_var(&a_in, text_labels[incoming]);
    lv_anim_set_values(&a_in, incoming_start_y, 0);
    lv_anim_set_time(&a_in, SCROLL_ANIM_MS);
    lv_anim_set_path_cb(&a_in, lv_anim_path_ease_in_out);
    lv_anim_start(&a_in);

    active_label = incoming;
    displayed_page = idx;
}

static struct ebook_page_state ebook_page_get_state(const zmk_event_t *eh) {
    const struct zmk_ebook_page_changed *ev = as_zmk_ebook_page_changed(eh);
    return (struct ebook_page_state){
        .page_idx = (ev != NULL) ? ev->page_idx : ebook_current_page,
    };
}

ZMK_DISPLAY_WIDGET_LISTENER(widget_ebook_page, struct ebook_page_state, set_ebook_page,
                             ebook_page_get_state)
ZMK_SUBSCRIPTION(widget_ebook_page, zmk_ebook_page_changed);
