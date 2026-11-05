-- --- Touchpad gestures ---
-- Layout:
--   no modifier -> navigation
--   SUPER       -> window manipulation (like SUPER + mouse drag/resize)
--   ALT         -> media
-- 2 fingers without a modifier are left to apps (pinch-zoom, scrolling, back/forward).
-- Workspace swipes are natural/inverted: fingers left = next workspace. 4-finger and
-- media swipes follow the same direction.
--
-- Every gesture is also recorded in the HyprBinds registry (keybinds.lua), so it shows
-- up in scripts/list_keybinds.sh.
-- Docs: https://wiki.hypr.land/configuring/core/binds/gestures/

local util = require("categories.util")

hl.config({
    gestures = {
        workspace_swipe_cancel_ratio   = 0.15, -- a short swipe is enough to switch
        workspace_swipe_create_new     = true, -- swiping past the last workspace creates one
        workspace_swipe_direction_lock = true, -- diagonal swipes don't jitter
    },
})

-- gesture(spec, info)
--   spec: passed to hl.gesture
--   info: { keys, category, description, run, repeating }
--         run: dispatcher/function used when the entry is picked in the keybind list.
--              Defaults to spec.action when it's a plain function. Without one, the
--              entry is listed but can't be run (1:1 gestures like move/resize).
local function gesture(spec, info)
    hl.gesture(spec)

    local run = info.run
    if run == nil and type(spec.action) == "function" then
        run = spec.action
    end

    HyprBinds.register({
        keys        = info.keys,
        action      = run,
        category    = info.category,
        description = info.description,
        repeating   = info.repeating == true,
        runnable    = run ~= nil,
    })
end

-- --- Actions ---

-- Window.fullscreen values
local FS_NONE, FS_MAXIMIZED = 0, 1

-- Grow: tiled -> maximized (bar visible) -> fullscreen
local function grow()
    local w = hl.get_active_window()
    if w == nil then
        return
    end
    if w.fullscreen == FS_NONE then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "set" }))
    elseif w.fullscreen == FS_MAXIMIZED then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "set" }))
    end
end

-- Shrink: fullscreen -> maximized -> tiled
local function shrink()
    local w = hl.get_active_window()
    if w == nil then
        return
    end
    if w.fullscreen > FS_MAXIMIZED then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "set" }))
    elseif w.fullscreen == FS_MAXIMIZED then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "unset" }))
    end
end

-- Move the active window to the workspace next to it and follow it there.
-- Uses the absolute workspace id for both steps, so it works whether or not
-- window.move already follows.
local function carry(offset)
    return function()
        local w = hl.get_active_window()
        if w == nil or w.workspace == nil or w.workspace.special or w.workspace.id == nil then
            return
        end
        local target = w.workspace.id + offset
        if target < 1 then
            return
        end
        hl.dispatch(hl.dsp.window.move({ workspace = target }))
        hl.dispatch(hl.dsp.focus({ workspace = target }))
    end
end

-- Float + center a tiled window (no-op if it already floats)
local function pop_out()
    local w = hl.get_active_window()
    if w ~= nil and not w.floating then
        util.float_and_center()
    end
end

-- Tile a floating window again (no-op if it's already tiled)
local function tile()
    local w = hl.get_active_window()
    if w ~= nil and w.floating then
        hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    end
end

local function launcher()
    hl.dispatch(hl.dsp.exec_cmd("pkill wofi || wofi --show drun"))
end

-- Live volume: up = louder. Motion is collected until it adds up to whole percent,
-- so a swipe doesn't spawn a wpctl process for every touchpad event.
local VOLUME_PER_PIXEL = 0.25
local volume_acc = 0

local function volume_update(e)
    volume_acc = volume_acc - VOLUME_PER_PIXEL * e.delta.y
    local step = math.modf(volume_acc)
    if step ~= 0 then
        volume_acc = volume_acc - step
        hl.exec_cmd(string.format(
            "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ %d%%%s && hyprosd show volume",
            math.abs(step), step > 0 and "+" or "-"))
    end
end

local function media(cmd)
    return function()
        hl.dispatch(hl.dsp.exec_cmd("playerctl " .. cmd))
    end
end

-- --- Navigation (no modifier) ---
gesture({ fingers = 3, direction = "horizontal", action = "workspace" },
    { keys = "3F ←→", category = "Gestures", description = "Switch Workspace" })
gesture({ fingers = 3, direction = "up", action = grow },
    { keys = "3F ↑", category = "Gestures", description = "Grow: Tiled → Maximized → Fullscreen", repeating = true })
gesture({ fingers = 3, direction = "down", action = shrink },
    { keys = "3F ↓", category = "Gestures", description = "Shrink: Fullscreen → Maximized → Tiled", repeating = true })

gesture({ fingers = 4, direction = "left", action = carry(1) },
    { keys = "4F ←", category = "Gestures", description = "Carry Window to Next Workspace", repeating = true })
gesture({ fingers = 4, direction = "right", action = carry(-1) },
    { keys = "4F →", category = "Gestures", description = "Carry Window to Previous Workspace", repeating = true })
gesture({ fingers = 4, direction = "up", action = launcher },
    { keys = "4F ↑", category = "Gestures", description = "App Launcher" })
gesture({ fingers = 4, direction = "down", action = "close" },
    { keys = "4F ↓", category = "Gestures", description = "Close Window", run = hl.dsp.window.close() })

gesture({ fingers = 4, direction = "pinchout", action = pop_out },
    { keys = "4F pinch out", category = "Gestures", description = "Float + Center Window" })
gesture({ fingers = 4, direction = "pinchin", action = tile },
    { keys = "4F pinch in", category = "Gestures", description = "Tile Window" })

-- --- Window manipulation (SUPER) ---
gesture({ fingers = 3, direction = "swipe", mods = "SUPER", action = "move" },
    { keys = "SUPER + 3F swipe", category = "Gestures", description = "Move Window" })
gesture({ fingers = 2, direction = "pinch", mods = "SUPER", action = "resize" },
    { keys = "SUPER + 2F pinch", category = "Gestures", description = "Resize Window" })
gesture({ fingers = 3, direction = "pinch", mods = "SUPER", action = "cursor_zoom", zoom_level = 1, mode = "live" },
    { keys = "SUPER + 3F pinch", category = "Gestures", description = "Magnifier (Zoom at Cursor)" })

-- --- Media (ALT) ---
gesture({
    fingers   = 3,
    direction = "vertical",
    mods      = "ALT",
    action    = {
        start  = function(e) volume_acc = 0; volume_update(e) end,
        update = volume_update,
    },
}, { keys = "ALT + 3F ↑↓", category = "Gestures", description = "Volume" })
gesture({ fingers = 3, direction = "left", mods = "ALT", action = media("next") },
    { keys = "ALT + 3F ←", category = "Gestures", description = "Next Track", repeating = true })
gesture({ fingers = 3, direction = "right", mods = "ALT", action = media("previous") },
    { keys = "ALT + 3F →", category = "Gestures", description = "Previous Track", repeating = true })
