-- --- Some default env vars ---
hl.env("XCURSOR_SIZE", "24")

-- --- Qt Theme workaround ---
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
