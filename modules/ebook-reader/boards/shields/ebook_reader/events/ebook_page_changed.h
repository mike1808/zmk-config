#pragma once

#include <zephyr/kernel.h>
#include <zmk/event_manager.h>

struct zmk_ebook_page_changed {
    uint16_t page_idx;
};

ZMK_EVENT_DECLARE(zmk_ebook_page_changed);

static inline int raise_ebook_page_changed(uint16_t page_idx) {
    return raise_zmk_ebook_page_changed(
        (struct zmk_ebook_page_changed){.page_idx = page_idx});
}
