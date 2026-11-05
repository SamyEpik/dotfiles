local colors = require("categories.colors")

hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 20,
        border_size = 2,

        col = {
            active_border   = colors.color13,
            inactive_border = colors.color0,
        },

        layout = "dwindle",
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
    },

    decoration = {
        rounding = 10,

        blur = {
            size              = 7,
            passes            = 2,
            new_optimizations = true,
        },

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "rgba(1a1a1aee)",
        },
    },
})
