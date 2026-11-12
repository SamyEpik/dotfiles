pragma Singleton

import QtQuick
import Quickshell

// Fire-and-forget command helpers. execDetached runs no shell, so wrap shell syntax in sh -c.
Singleton {
    // Shell command line, e.g. Run.sh("pkill wofi || ~/.dotfiles/scripts/system_menu.sh --menu")
    function sh(cmd: string): void {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    // "kitty floating": Hyprland rules float + centre the `floating` class. Keep the class.
    //
    // Toggles (user request 2026-11-11, like `pkill wofi || ...` for the clipboard): a second
    // click on the same bar item closes its window instead of opening another one. Each command
    // gets a marker in kitty's command line, `--instance-group qsbar-<key>` (ignored without
    // --single-instance, so the window and its rules are unchanged). The pattern is anchored at
    // `^kitty`, so it never matches this `sh -c` wrapper itself.
    function floating(cmd: string): void {
        const key = "qsbar-" + cmd.replace(/[^A-Za-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 48);
        sh("pkill -f '^kitty .*--instance-group " + key + "( |$)' || exec kitty -o confirm_os_window_close=0"
           + " --class floating --instance-group " + key + " " + cmd);
    }

    // Hyprland dispatch in Lua syntax, e.g. Run.dispatch('hl.dsp.focus({ workspace = 9 })')
    function dispatch(lua: string): void {
        Quickshell.execDetached(["hyprctl", "dispatch", lua]);
    }
}
