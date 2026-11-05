-- --- Shared helpers ---
-- Not a config category: required by keybinds.lua and gestures.lua, not by hyprland.lua.
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

return M
