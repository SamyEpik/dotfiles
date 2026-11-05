-- --- Monitor configuration ---
hl.monitor({ output = "eDP-1", mode = "1920x1200", position = "0x2160", scale = 1 })
hl.monitor({ output = "DP-3",  mode = "3840x2160", position = "0x0",    scale = 1 })

-- for external monitors
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
