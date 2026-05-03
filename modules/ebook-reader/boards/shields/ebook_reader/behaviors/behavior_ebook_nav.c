#define DT_DRV_COMPAT zmk_behavior_ebook_nav

#include <zephyr/device.h>
#include <drivers/behavior.h>
#include <zephyr/logging/log.h>

#include <zmk/behavior.h>

#include "../ebook_data.h"
#include "../events/ebook_page_changed.h"

LOG_MODULE_DECLARE(zmk, CONFIG_ZMK_LOG_LEVEL);

#if DT_HAS_COMPAT_STATUS_OKAY(DT_DRV_COMPAT)

static uint16_t page_idx = 0;

struct behavior_ebook_nav_config {
    uint8_t direction;
};

static int on_keymap_binding_pressed(struct zmk_behavior_binding *binding,
                                     struct zmk_behavior_binding_event event) {
    const struct device *dev = zmk_behavior_get_binding(binding->behavior_dev);
    const struct behavior_ebook_nav_config *cfg = dev->config;

    if (cfg->direction == 1) {
        if (page_idx < ebook_total_pages - 1) {
            page_idx++;
        }
    } else {
        if (page_idx > 0) {
            page_idx--;
        }
    }

    raise_ebook_page_changed(page_idx);
    return ZMK_BEHAVIOR_OPAQUE;
}

static int on_keymap_binding_released(struct zmk_behavior_binding *binding,
                                      struct zmk_behavior_binding_event event) {
    return ZMK_BEHAVIOR_OPAQUE;
}

static const struct behavior_driver_api behavior_ebook_nav_driver_api = {
    .binding_pressed = on_keymap_binding_pressed,
    .binding_released = on_keymap_binding_released,
};

#define EBOOK_NAV_INST(n)                                                                          \
    static const struct behavior_ebook_nav_config behavior_ebook_nav_config_##n = {               \
        .direction = DT_INST_PROP(n, direction),                                                   \
    };                                                                                             \
    BEHAVIOR_DT_INST_DEFINE(n, NULL, NULL, NULL, &behavior_ebook_nav_config_##n, POST_KERNEL,     \
                            CONFIG_KERNEL_INIT_PRIORITY_DEFAULT,                                   \
                            &behavior_ebook_nav_driver_api);

DT_INST_FOREACH_STATUS_OKAY(EBOOK_NAV_INST)

#endif /* DT_HAS_COMPAT_STATUS_OKAY(DT_DRV_COMPAT) */
