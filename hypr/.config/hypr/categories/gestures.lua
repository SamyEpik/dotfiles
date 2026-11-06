-- --- Touchpad gestures ---
-- Layout:
--   no modifier -> navigation
--   SUPER       -> window manipulation (like SUPER + mouse drag/resize)
--   ALT         -> media
-- 2 fingers without a modifier are left to apps (pinch-zoom, scrolling, back/forward).
-- Workspace swipes are natural/inverted: fingers left = next workspace. 4-finger and
-- media swipes follow the same direction.
--
-- The actions live in util.lua and are shared with the touchscreen (touch.lua).
-- Every gesture is also recorded in the HyprBinds registry (keybinds.lua), so it
-- shows up in scripts/list_keybinds.sh.
-- Docs: https://wiki.hypr.land/configuring/core/binds/gestures/

local util = require("categories.util")

hl.config({
    gestures = {
        workspace_swipe_cancel_ratio   = 0.15, -- a short swipe is enough to switch
        workspace_swipe_create_new     = true, -- swiping past the last workspace creates one
        workspace_swipe_direction_lock = true, -- diagonal swipes don't jitter
    },
})

-- gesture(spec, info): hl.gesture + registry entry (see util.register_gesture)
local function gesture(spec, info)
    hl.gesture(spec)
    util.register_gesture(spec.action, info)
end

local CAT = "Touchpad Gestures"

-- --- Navigation (no modifier) ---
gesture({ fingers = 3, direction = "horizontal", action = "workspace" },
    { keys = "3F ←→", category = CAT, description = "Switch Workspace" })
gesture({ fingers = 3, direction = "up", action = util.grow },
    { keys = "3F ↑", category = CAT, description = "Grow: Tiled → Maximized → Fullscreen", repeating = true })
gesture({ fingers = 3, direction = "down", action = util.shrink },
    { keys = "3F ↓", category = CAT, description = "Shrink: Fullscreen → Maximized → Tiled", repeating = true })

gesture({ fingers = 4, direction = "left", action = util.carry(1) },
    { keys = "4F ←", category = CAT, description = "Carry Window to Next Workspace", repeating = true })
gesture({ fingers = 4, direction = "right", action = util.carry(-1) },
    { keys = "4F →", category = CAT, description = "Carry Window to Previous Workspace", repeating = true })
gesture({ fingers = 4, direction = "up", action = util.launcher },
    { keys = "4F ↑", category = CAT, description = "App Launcher" })
gesture({ fingers = 4, direction = "down", action = "close" },
    { keys = "4F ↓", category = CAT, description = "Close Window", run = hl.dsp.window.close() })

gesture({ fingers = 4, direction = "pinchout", action = util.pop_out },
    { keys = "4F pinch out", category = CAT, description = "Float + Center Window" })
gesture({ fingers = 4, direction = "pinchin", action = util.tile },
    { keys = "4F pinch in", category = CAT, description = "Tile Window" })

-- --- Window manipulation (SUPER) ---
gesture({ fingers = 3, direction = "swipe", mods = "SUPER", action = "move" },
    { keys = "SUPER + 3F swipe", category = CAT, description = "Move Window" })
gesture({ fingers = 2, direction = "pinch", mods = "SUPER", action = "resize" },
    { keys = "SUPER + 2F pinch", category = CAT, description = "Resize Window" })
gesture({ fingers = 3, direction = "pinch", mods = "SUPER", action = "cursor_zoom", zoom_level = 1, mode = "live" },
    { keys = "SUPER + 3F pinch", category = CAT, description = "Magnifier (Zoom at Cursor)" })

-- --- Media (ALT) ---
gesture({ fingers = 3, direction = "vertical", mods = "ALT", action = util.live_slider(0.25, util.volume_cmd) },
    { keys = "ALT + 3F ↑↓", category = CAT, description = "Volume" })
gesture({ fingers = 3, direction = "left", mods = "ALT", action = util.media("next") },
    { keys = "ALT + 3F ←", category = CAT, description = "Next Track", repeating = true })
gesture({ fingers = 3, direction = "right", mods = "ALT", action = util.media("previous") },
    { keys = "ALT + 3F →", category = CAT, description = "Previous Track", repeating = true })
