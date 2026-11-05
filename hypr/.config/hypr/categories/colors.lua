-- --- Colors from pywal ---
-- ~/.cache/wal/colors-hyprland.lua is rendered from
-- ~/.dotfiles/wal/.config/wal/templates/colors-hyprland.lua.
-- Requiring it by explicit path makes Hyprland watch the file, so a new
-- pywal theme is applied automatically (same as the old `source =`).

-- Fallback palette, used until pywal has generated its cache (e.g. fresh install)
local fallback = {
    foreground = "rgba(195,193,197,1.0)",
    background = "rgba(15,9,23,1.0)",
    color0     = "rgba(15,9,23,1.0)",
    color13    = "rgba(244,164,189,1.0)",
}

local ok, colors = pcall(require, "~/.cache/wal/colors-hyprland")

if not ok or type(colors) ~= "table" then
    return fallback
end

return colors
