-- --- Keybinds ---
local mainMod = "SUPER"
local MENU    = "$HOME/.dotfiles/scripts/system_menu.sh"

-- --- Keybind registry ---
-- In Lua mode `hyprctl binds` only reports binds as dispatcher "__lua", so every
-- bind registered through bind() below is also recorded here. The global is
-- reachable from the shell (used by scripts/list_keybinds.sh):
--   hyprctl repl 'return HyprBinds.dump()'   -> one tab-separated line per bind:
--                                               id, category, keys, description, repeating, runnable
--   hyprctl eval 'HyprBinds.run(3)'          -> run bind #3
HyprBinds = { list = {} }

function HyprBinds.dump()
    local lines = {}
    for i, b in ipairs(HyprBinds.list) do
        lines[#lines + 1] = table.concat({ i, b.category, b.keys, b.description, tostring(b.repeating), tostring(b.runnable) }, "\t")
    end
    return table.concat(lines, "\n")
end

function HyprBinds.run(id)
    local b = HyprBinds.list[tonumber(id)]
    if b == nil then
        error("HyprBinds.run: no keybind with id " .. tostring(id))
    end
    if not b.runnable then
        error("HyprBinds.run: '" .. b.description .. "' can't be run from a menu")
    end
    return hl.dispatch(b.action)
end

-- Add an entry to the registry without binding anything (used by gestures.lua).
-- entry: { keys, action, category, description, repeating, runnable }
function HyprBinds.register(entry)
    table.insert(HyprBinds.list, entry)
end

-- bind(keys, action, category, description, opts)
-- opts are passed to hl.bind, plus `runnable = false` to hide the "run" option (mouse binds)
local function bind(keys, action, category, description, opts)
    opts = opts or {}
    local runnable = opts.runnable ~= false
    opts.runnable = nil
    opts.description = description

    hl.bind(keys, action, opts)

    HyprBinds.register({
        keys        = keys,
        action      = action,
        category    = category,
        description = description,
        repeating   = opts.repeating == true,
        runnable    = runnable,
    })
end

local function exec(cmd)
    return hl.dsp.exec_cmd(cmd)
end

local float_and_center = require("categories.util").float_and_center

-- Binds for programs
bind(mainMod .. " + E", exec("thunar"), "Programs", "File Manager")
bind(mainMod .. " + R", exec("pkill wofi || wofi --show drun"), "Programs", "App Launcher")
bind(mainMod .. " + B", exec("firefox"), "Programs", "Web Browser")
bind(mainMod .. " + Q", exec("kitty"), "Programs", "Terminal")
bind(mainMod .. " + SHIFT + L", exec("hyprlock"), "System", "Lock Screen")
bind(mainMod .. " + V", exec("pkill wofi || cliphist list | wofi --dmenu --allow-images | cliphist decode | wl-copy"), "Programs", "Clipboard History")
bind(mainMod .. " + A", exec("pkill wofi || " .. MENU .. " --menu"), "System", "System Menu")

-- Binds for actions
bind(mainMod .. " + C", hl.dsp.window.close(), "Windows", "Close Window")
bind(mainMod .. " + SHIFT + E", hl.dsp.exit(), "System", "Exit Hyprland")
bind(mainMod .. " + W", hl.dsp.window.float({ action = "toggle" }), "Windows", "Toggle Floating")
bind(mainMod .. " + SHIFT + W", float_and_center, "Windows", "Float and Center")
bind(mainMod .. " + F", hl.dsp.window.fullscreen(), "Windows", "Toggle Fullscreen")

-- Move focus with mainMod + arrow keys or mainMod + vim keybinds (h,j,k,l)
local directions = {
    { dir = "left",  arrow = "left",  vim = "H" },
    { dir = "right", arrow = "right", vim = "L" },
    { dir = "up",    arrow = "up",    vim = "K" },
    { dir = "down",  arrow = "down",  vim = "J" },
}
for _, d in ipairs(directions) do
    local action = hl.dsp.focus({ direction = d.dir })
    bind(mainMod .. " + " .. d.arrow, action, "Focus", "Move Focus " .. d.dir)
    bind(mainMod .. " + " .. d.vim, action, "Focus", "Move Focus " .. d.dir)
end

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- workspace 10 is on key 0
    bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }), "Workspaces", "Go to Workspace " .. i)
    bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), "Workspaces", "Move Window to Workspace " .. i)
end

-- Scroll through existing workspaces with mainMod + scroll
bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Workspaces", "Next Workspace")
bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), "Workspaces", "Previous Workspace")

-- Move/resize windows with mainMod + LMB/RMB and dragging
bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), "Mouse", "Move Window", { mouse = true, runnable = false })
bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), "Mouse", "Resize Window", { mouse = true, runnable = false })

-- Volume and media control
bind("XF86AudioRaiseVolume", exec("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+ && hyprosd show volume"), "Media", "Volume Up")
bind("XF86AudioLowerVolume", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && hyprosd show volume"), "Media", "Volume Down")
bind("XF86AudioMicMute", exec("wpctl set-mute @DEFAULT_SOURCE@ toggle"), "Media", "Mic Mute")
bind("XF86AudioMute", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && hyprosd show volume"), "Media", "Mute/Unmute")
bind("XF86AudioNext", exec("playerctl next"), "Media", "Next Track")
bind("XF86AudioPrev", exec("playerctl previous"), "Media", "Previous Track")

-- Screen brightness
bind("XF86MonBrightnessUp", exec("brightnessctl s +5% && hyprosd show brightness"), "Media", "Brightness Up")
bind("XF86MonBrightnessDown", exec("brightnessctl s 5%- && hyprosd show brightness"), "Media", "Brightness Down")

-- Lock Screen when lid closed
bind("switch:on:Lid Switch", exec("hyprlock"), "System", "Lock when Lid closed", { locked = true })

-- Screenshot tool
bind("PRINT", exec("hyprshot -m window -r - | swappy -f -"), "Screenshots", "Screenshot Window")
bind(mainMod .. " + SHIFT + S", exec("grim -g \"$(slurp -b 00000090)\" - | swappy -f -"), "Screenshots", "Screenshot Region")
bind(mainMod .. " + SHIFT + PRINT", exec("grim -g \"$(slurp -b 00000090)\" - | swappy -f -"), "Screenshots", "Screenshot Region")

-- System menu: number keys select entries while the menu is open
-- (entered/left by scripts/system_menu.sh). Not part of the registry.
hl.define_submap("system_menu", function()
    for i = 1, 9 do
        hl.bind(tostring(i), exec(MENU .. " --pick " .. i))
    end
    hl.bind(mainMod .. " + A", exec("pkill -x wofi"))
end)
