-- --- Touchscreen ---
-- Native touch settings + gestures via the hyprgrass plugin
-- (https://github.com/horriblename/hyprgrass, installed with hyprpm, loaded in autostart.lua).
--
-- The multi-finger gestures mirror the touchpad layout in gestures.lua (same actions
-- from util.lua). Edge swipes are touch-only:
--   bottom edge ↑ -> app launcher        top edge ↓   -> system menu
--   right edge ↕  -> volume              left edge ↕  -> brightness
-- 1 finger is left to apps (taps, scrolling, long-press menus, text selection).
--
-- Everything plugin-related is behind `if hl.plugin.hyprgrass`, so the config still
-- loads when the plugin is missing or broken after a Hyprland update
-- (fix with `hyprpm update`).

local util = require("categories.util")

-- Map the panel to the built-in display. Without this, touches can land on the
-- external monitor when it's connected.
hl.config({
    input = {
        touchdevice = {
            output = "eDP-1",
        },
    },
})

local hg = hl.plugin.hyprgrass
if hg == nil then
    return
end

hl.config({
    plugin = {
        hyprgrass = {
            sensitivity                 = 4.0, -- the default (1.0) is too low for laptop screens
            long_press_delay            = 400, -- ms
            resize_on_border_long_press = true, -- long-press a border/gap to resize
            edge_margin                 = 15,   -- px from the screen edge that count as an edge
        },
    },
})

local CAT = "Touchscreen Gestures"

-- gesture(pattern, action, info, opts): hyprgrass.gesture + registry entry
local function gesture(pattern, action, info, opts)
    local spec = opts or {}
    spec.pattern = pattern
    spec.action = action
    hg.gesture(spec)
    util.register_gesture(action, info)
end

-- bind(pattern, action, info, opts): hyprgrass.bind + registry entry
local function bind(pattern, action, info, opts)
    local spec = opts or {}
    spec.pattern = pattern
    spec.action = action
    hg.bind(spec)
    util.register_gesture(action, info)
end

local function swipe(fingers, direction)
    return { kind = "swipe", fingers = fingers, direction = direction }
end

local function edge(origin, direction)
    return { kind = "edge", origin = origin, direction = direction }
end

-- --- Multi-finger (same as the touchpad) ---
gesture(swipe(3, "horizontal"), "workspace",
    { keys = "3F ←→", category = CAT, description = "Switch Workspace" })
gesture(swipe(3, "up"), util.grow,
    { keys = "3F ↑", category = CAT, description = "Grow: Tiled → Maximized → Fullscreen" })
gesture(swipe(3, "down"), util.shrink,
    { keys = "3F ↓", category = CAT, description = "Shrink: Fullscreen → Maximized → Tiled" })

gesture(swipe(4, "left"), util.carry(1),
    { keys = "4F ←", category = CAT, description = "Carry Window to Next Workspace" })
gesture(swipe(4, "right"), util.carry(-1),
    { keys = "4F →", category = CAT, description = "Carry Window to Previous Workspace" })
gesture(swipe(4, "up"), util.launcher,
    { keys = "4F ↑", category = CAT, description = "App Launcher" })
gesture(swipe(4, "down"), "close",
    { keys = "4F ↓", category = CAT, description = "Close Window", run = hl.dsp.window.close() })

-- pinch only exists for hyprgrass.bind, not hyprgrass.gesture
bind({ kind = "pinch", fingers = 4, direction = "pinchout" }, util.pop_out,
    { keys = "4F pinch out", category = CAT, description = "Float + Center Window" })
bind({ kind = "pinch", fingers = 4, direction = "pinchin" }, util.tile,
    { keys = "4F pinch in", category = CAT, description = "Tile Window" })

-- Long-press with 2 fingers and drag to move a window (touch version of SUPER + drag).
-- 1-finger long-press is left to apps (context menus, text selection).
bind({ kind = "longpress", fingers = 2 }, hl.dsp.window.drag(),
    { keys = "2F long press", category = CAT, description = "Move Window (hold + drag)", run = false },
    { mouse = true })
HyprBinds.register({
    keys = "long press border", category = CAT, description = "Resize Window (hold + drag)",
    repeating = false, runnable = false,
})

-- --- Edge swipes (touch only) ---
gesture(edge("down", "up"), util.launcher,
    { keys = "bottom edge ↑", category = CAT, description = "App Launcher" })
gesture(edge("up", "down"), util.system_menu,
    { keys = "top edge ↓", category = CAT, description = "System Menu" })

-- live sliders: the full panel height (1200 px) is ~120%
gesture(edge("right", "vertical"), util.live_slider(0.1, util.volume_cmd),
    { keys = "right edge ↕", category = CAT, description = "Volume" })
gesture(edge("left", "vertical"), util.live_slider(0.1, util.brightness_cmd),
    { keys = "left edge ↕", category = CAT, description = "Brightness" })
