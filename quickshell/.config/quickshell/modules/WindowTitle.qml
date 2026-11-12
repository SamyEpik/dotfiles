import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

// Focused window title (Waybar hyprland/window), fallback "Desktop". Tooltip: window class.
//
// Checked live on Quickshell 0.3.2 / Hyprland 0.57.1:
//  - Hyprland.activeToplevel stays null after startup until the next focus event, and its
//    wayland/lastIpcObject can be empty, so it can't be the main source.
//  - ToplevelManager.activeToplevel (Wayland foreign-toplevel) is set right away, and its
//    title/appId notify on change (tab switch, terminal title, ...).
// The Hyprland toplevel that wraps it gives the workspace, used for the "Desktop" fallback
// (the last active window may still count as active after switching to an empty workspace).
PillGroup {
    id: root

    // Max width of the whole pill. The shell sets it to the free space in the centre, so the
    // title elides instead of overlapping the side modules (Waybar/GTK squeezed it the same way).
    property real maxWidth: 1e9

    readonly property Toplevel active: ToplevelManager.activeToplevel
    readonly property HyprlandToplevel hyprActive: active
        ? Hyprland.toplevels.values.find(t => t.wayland === active) ?? null
        : null

    readonly property bool onFocusedWorkspace: {
        const ws = Hyprland.focusedWorkspace;
        if (!ws)
            return true;
        // Not mapped to a Hyprland window yet (only briefly, e.g. right after startup):
        // trust Wayland instead of flashing "Desktop".
        return hyprActive?.workspace ? hyprActive.workspace === ws : true;
    }

    readonly property Toplevel window: active && onFocusedWorkspace ? active : null
    readonly property string title: window?.title || "Desktop"
    readonly property string windowClass: window
        ? (window.appId || hyprActive?.lastIpcObject?.class || "")
        : ""

    Segment {
        id: seg
        tooltip: root.windowClass

        FancyText {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.foreground
            maxChars: 40
            maxWidth: Math.max(40, root.maxWidth - seg.leftPadding - seg.rightPadding - 2 * Theme.pillBorder)
            hovered: seg.hovered
            text: root.title
        }
    }
}
