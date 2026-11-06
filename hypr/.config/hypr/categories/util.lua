-- --- Shared helpers ---
-- Not a config category: required by keybinds.lua, gestures.lua and touch.lua,
-- not by hyprland.lua.
local M = {}

-- Float the active window, resize it to half of its monitor and center it
function M.float_and_center()
    local w = hl.get_active_window()
    if w == nil then
        return
    end

    hl.dispatch(hl.dsp.window.float({ action = "set" }))

    local m = w.monitor or hl.get_active_monitor()
    if m ~= nil then
        hl.dispatch(hl.dsp.window.resize({
            x = math.floor(m.width / m.scale / 2),
            y = math.floor(m.height / m.scale / 2),
        }))
    end

    -- center after resizing, otherwise the window ends up off-center
    hl.dispatch(hl.dsp.window.center())
end

-- Record a gesture in the HyprBinds registry (keybinds.lua) so it shows up in
-- scripts/list_keybinds.sh.
--   action: the gesture's action (string, function or live table)
--   info:   { keys, category, description, run, repeating }
--           run: dispatcher/function used when the entry is picked in the keybind
--                list. Defaults to `action` when it's a plain function. Without one
--                (or with run = false), the entry is listed but can't be run
--                (1:1 / live / mouse gestures).
function M.register_gesture(action, info)
    local run = info.run
    if run == nil and type(action) == "function" then
        run = action
    elseif run == false then
        run = nil
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

-- --- Window actions (used by touchpad + touchscreen gestures) ---

-- Window.fullscreen values
local FS_NONE, FS_MAXIMIZED = 0, 1

-- Grow: tiled -> maximized (bar visible) -> fullscreen
function M.grow()
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
function M.shrink()
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

-- Returns a function that moves the active window to the workspace next to it and
-- follows it there. Uses the absolute workspace id for both steps, so it works
-- whether or not window.move already follows.
function M.carry(offset)
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
function M.pop_out()
    local w = hl.get_active_window()
    if w ~= nil and not w.floating then
        M.float_and_center()
    end
end

-- Tile a floating window again (no-op if it's already tiled)
function M.tile()
    local w = hl.get_active_window()
    if w ~= nil and w.floating then
        hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    end
end

function M.launcher()
    hl.dispatch(hl.dsp.exec_cmd("pkill wofi || wofi --show drun"))
end

function M.system_menu()
    hl.dispatch(hl.dsp.exec_cmd("pkill wofi || $HOME/.dotfiles/scripts/system_menu.sh --menu"))
end

-- Returns a function that runs `playerctl <cmd>`
function M.media(cmd)
    return function()
        hl.dispatch(hl.dsp.exec_cmd("playerctl " .. cmd))
    end
end

-- --- Live sliders ---

-- live_slider(per_pixel, command) -> live gesture table { start, update }
-- Vertical motion up = increase. Motion is collected until it adds up to a whole
-- percent, so a swipe doesn't spawn a process for every input event.
-- command(step) returns the shell command for a change of `step` percent (never 0).
function M.live_slider(per_pixel, command)
    local acc = 0

    local function update(e)
        acc = acc - per_pixel * e.delta.y
        local step = math.modf(acc)
        if step ~= 0 then
            acc = acc - step
            hl.exec_cmd(command(math.tointeger(step)))
        end
    end

    return {
        start  = function(e) acc = 0; update(e) end,
        update = update,
    }
end

local function signed(step)
    return string.format("%d%%%s", math.abs(step), step > 0 and "+" or "-")
end

function M.volume_cmd(step)
    return "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " .. signed(step) .. " && hyprosd show volume"
end

-- brightnessctl takes "N%-" for down and "+N%" for up; never goes below 5%
function M.brightness_cmd(step)
    local arg = step > 0 and string.format("+%d%%", step) or string.format("%d%%-", -step)
    return "brightnessctl -q set --min-value=5% " .. arg .. " && hyprosd show brightness"
end

return M
