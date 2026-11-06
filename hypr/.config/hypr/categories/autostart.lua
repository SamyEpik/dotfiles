-- --- Execute scripts and background processes on startup ---
-- "hyprland.start" fires once per session, so this is the Lua equivalent of exec-once.
hl.on("hyprland.start", function()
    hl.exec_cmd("dunst")
    hl.exec_cmd("waybar")
    hl.exec_cmd("$HOME/.config/waybar/waybar-mediaplayer/src/mediaplayer monitor > /tmp/waybar-mediaplayer-output")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("/usr/lib/mate-polkit/polkit-mate-authentication-agent-1")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("batsignal -w 20 -c 10 -d 5")
    hl.exec_cmd("FORCE_LIGHT=\"--force-light\" waypaper --restore")
    hl.exec_cmd("hyprosd daemon")

    -- load hyprpm plugins (hyprgrass, see touch.lua), then reload the config so
    -- the `if hl.plugin.hyprgrass` blocks run with the plugin present.
    -- -n: notify if a plugin needs `hyprpm update` after a Hyprland update
    hl.exec_cmd("hyprpm reload -n && hyprctl reload")

    -- for screensharing
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")

    -- --- Execute programs on startup ---
    hl.exec_cmd("kitty",   { workspace = "1 silent" })
    hl.exec_cmd("firefox", { workspace = "2 silent" })
    hl.exec_cmd("spotifast")
    hl.exec_cmd("webcord %U")

    -- --- Gtk Theme workaround ---
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface font-name 'Noto Sans'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme 'Catppuccin-Mocha-Dark-Cursors'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
end)
