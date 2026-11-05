hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "up",         action = "fullscreen" })
hl.gesture({ fingers = 3, direction = "down",       action = "fullscreen" })
hl.gesture({ fingers = 2, direction = "pinchout",   action = "move" })
hl.gesture({ fingers = 2, direction = "pinchin",    action = "resize" })

-- a plain function runs once when the swipe ends
hl.gesture({
    fingers   = 4,
    direction = "swipe",
    action    = function()
        hl.dispatch(hl.dsp.exec_cmd("hyprlock"))
    end,
})
