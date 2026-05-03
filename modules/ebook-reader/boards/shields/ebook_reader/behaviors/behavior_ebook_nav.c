#define DT_DRV_COMPAT zmk_behavior_ebook_nav

#include <zephyr/device.h>
#include <zephyr/settings/settings.h>
#include <drivers/behavior.h>
#include <zephyr/logging/log.h>

#include <zmk/behavior.h>

#include "../ebook_data.h"
#include "../events/ebook_page_changed.h"

LOG_MODULE_DECLARE(zmk, CONFIG_ZMK_LOG_LEVEL);

#if DT_HAS_COMPAT_STATUS_OKAY(DT_DRV_COMPAT)

uint16_t ebook_current_page = 0;

#if IS_ENABLED(CONFIG_SETTINGS)

static int ebook_settings_load_cb(const char *name, size_t len, settings_read_cb read_cb,
                                   void *cb_arg) {
    const char *next;
    if (settings_name_steq(name, "page", &next) && !next) {
        if (len != sizeof(ebook_current_page)) {
            return -EINVAL;
        }
        return read_cb(cb_arg, &ebook_current_page, sizeof(ebook_current_page));
    }
    return -ENOENT;
}

SETTINGS_STATIC_HANDLER_DEFINE(ebook, "ebook", NULL, ebook_settings_load_cb, NULL, NULL);

static void ebook_save_work_handler(struct k_work *work) {
    settings_save_one("ebook/page", &ebook_current_page, sizeof(ebook_current_page));
}

static struct k_work_delayable ebook_save_work;

#endif /* IS_ENABLED(CONFIG_SETTINGS) */

struct behavior_ebook_nav_config {
    uint8_t direction;
};

static int ebook_nav_init(const struct device *dev) {
#if IS_ENABLED(CONFIG_SETTINGS)
    k_work_init_delayable(&ebook_save_work, ebook_save_work_handler);
#endif
    return 0;
}

static int on_keymap_binding_pressed(struct zmk_behavior_binding *binding,
                                     struct zmk_behavior_binding_event event) {
    const struct device *dev = zmk_behavior_get_binding(binding->behavior_dev);
    const struct behavior_ebook_nav_config *cfg = dev->config;

    if (cfg->direction == 1) {
        if (ebook_current_page < ebook_total_pages - 1) {
            ebook_current_page++;
        }
    } else {
        if (ebook_current_page > 0) {
            ebook_current_page--;
        }
    }

    raise_ebook_page_changed(ebook_current_page);

#if IS_ENABLED(CONFIG_SETTINGS)
    k_work_reschedule(&ebook_save_work, K_NO_WAIT);
#endif

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
    BEHAVIOR_DT_INST_DEFINE(n, ebook_nav_init, NULL, NULL, &behavior_ebook_nav_config_##n,        \
                            POST_KERNEL, CONFIG_KERNEL_INIT_PRIORITY_DEFAULT,                      \
                            &behavior_ebook_nav_driver_api);

DT_INST_FOREACH_STATUS_OKAY(EBOOK_NAV_INST)

#endif /* DT_HAS_COMPAT_STATUS_OKAY(DT_DRV_COMPAT) */
