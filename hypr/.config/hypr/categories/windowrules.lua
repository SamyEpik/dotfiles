-- opacity
local OPACITY = "0.9"

-- default size for floating windows
local FLOAT_SIZE = { 860, 645 }

-- --- Window Rules for programs ---
local opacity_classes = {
    { name = "firefox",       class = "^(firefox)$" },
    { name = "obsidian",      class = "^(md.obsidian.Obsidian)$" },
    { name = "jetbrains-idea", class = "^(jetbrains-idea)$" },
    { name = "thunar",        class = "^(thunar)$" },
    { name = "wofi",          class = "^(wofi)$" },
    { name = "kitty",         class = "^(kitty)$" },
}

for _, app in ipairs(opacity_classes) do
    hl.window_rule({
        name    = "opacity-" .. app.name,
        match   = { class = app.class },
        opacity = OPACITY,
    })
end

hl.window_rule({
    name      = "opacity-spotify",
    match     = { class = "^(spotifast)$" },
    opacity   = OPACITY,
    workspace = "9 silent",
})

hl.window_rule({
    name      = "opacity-webcord",
    match     = { class = "^(webcord)$" },
    opacity   = OPACITY,
    workspace = "10 silent",
})

hl.window_rule({
    name    = "floating-opacity-waypaper",
    match   = { class = "^(waypaper)$" },
    opacity = OPACITY,
    float   = true,
    center  = true,
    size    = FLOAT_SIZE,
})

-- sets programs with --class floating to floating
hl.window_rule({
    name   = "float-class-floating",
    match  = { class = "floating" },
    float  = true,
    size   = FLOAT_SIZE,
    center = true,
})

hl.window_rule({
    name   = "float-class-share-picker",
    match  = { class = "hyprland-share-picker" },
    float  = true,
    size   = FLOAT_SIZE,
    center = true,
})

-- --- Bitwarden Firefox extension popup ---
-- A static title rule can't catch this: Firefox opens the popup with a generic
-- title and only renames it afterwards. Instead, react to the title change.
-- Already-floating windows are skipped so a moved/resized popup isn't snapped back.
local function float_bitwarden(w)
    if w == nil or w.floating then
        return
    end

    if not string.find(w.title, "Extension: (Bitwarden Password Manager)", nil, true) then
        return
    end

    hl.dispatch(hl.dsp.window.float({ action = "set", window = w }))
    hl.dispatch(hl.dsp.window.resize({ x = FLOAT_SIZE[1], y = FLOAT_SIZE[2], window = w }))
    hl.dispatch(hl.dsp.window.center({ window = w }))
end

hl.on("window.open", float_bitwarden)
hl.on("window.title", float_bitwarden)
