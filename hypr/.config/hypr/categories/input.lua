-- --- Configuring hyprland variables ---
hl.config({
    input = {
        kb_layout  = "de",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        touchpad = {
            natural_scroll       = true,
            clickfinger_behavior = true, -- 2-finger click = right click, 3-finger click = middle click
            disable_while_typing = true,
        },

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.
    },
})

hl.device({
    name          = "glorious-model-o",
    accel_profile = "flat",
})
