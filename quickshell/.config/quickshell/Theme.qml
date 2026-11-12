pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Pywal colours (live, from ~/.cache/wal/colors.json) plus the bar's fixed style constants.
Singleton {
    id: root

    // ---- pywal --------------------------------------------------------------------------
    // Fallback palette = the pywal theme active on 2026-11-09. Only used if colors.json is
    // missing or unparsable.
    readonly property var _fallback: ({
        special: { background: "#1a0e22", foreground: "#c5c2c7" },
        colors: {
            color0: "#1a0e22", color1: "#A28A6F", color2: "#5B368C", color3: "#77598B",
            color4: "#976C9F", color5: "#B678B3", color6: "#B288B6", color7: "#c5c2c7",
            color8: "#6a5e72", color9: "#A28A6F", color10: "#5B368C", color11: "#77598B",
            color12: "#976C9F", color13: "#B678B3", color14: "#B288B6", color15: "#c5c2c7"
        }
    })
    property var wal: _fallback

    function _c(group, key) {
        const v = wal?.[group]?.[key] ?? _fallback[group][key];
        return String(v).toLowerCase();
    }

    readonly property color background: _c("special", "background")
    readonly property color foreground: _c("special", "foreground")
    readonly property color color0: _c("colors", "color0")
    readonly property color color1: _c("colors", "color1")
    readonly property color color2: _c("colors", "color2")
    readonly property color color3: _c("colors", "color3")
    readonly property color color4: _c("colors", "color4")
    readonly property color color5: _c("colors", "color5")
    readonly property color color6: _c("colors", "color6")
    readonly property color color7: _c("colors", "color7")
    readonly property color color8: _c("colors", "color8")

    FileView {
        id: walFile
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                if (parsed?.special && parsed?.colors)
                    root.wal = parsed;
            } catch (e) {
                // pywal can be mid-write; keep the previous palette, the next change fires again.
                console.warn("Theme: could not parse colors.json:", e);
            }
        }
        onLoadFailed: err => console.warn("Theme: colors.json not loaded, using fallback palette:", err)
    }

    // ---- contrast -----------------------------------------------------------------------
    // WCAG contrast ratio of two colours.
    function contrast(a: color, b: color): real {
        const lum = c => {
            const f = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
            return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
        };
        const la = lum(a), lb = lum(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    // What a pill really looks like behind its text: `background` at pillOpacity over an average
    // (mid-grey) wallpaper. Measuring against plain `background` was too optimistic, because the
    // translucent pill gets much lighter over bright wallpapers (user 2026-11-11: icons still faint).
    readonly property color pillBackdrop: Qt.rgba(
        background.r * pillOpacity + 0.5 * (1 - pillOpacity),
        background.g * pillOpacity + 0.5 * (1 - pillOpacity),
        background.b * pillOpacity + 0.5 * (1 - pillOpacity), 1)

    // `c` lightened in HSL steps (same hue) until it reaches `minRatio` against pillBackdrop.
    // Used where a pywal colour is too dark to read (battery color2, network color3, bluetooth color4).
    function readable(c: color, minRatio: real): color {
        let out = c;
        for (let i = 0; i < 20 && contrast(out, pillBackdrop) < minRatio; i++)
            out = Qt.hsla(out.hslHue, out.hslSaturation, Math.min(1, out.hslLightness + 0.04), out.a);
        return out;
    }

    // ---- bar geometry (Waybar style.css) ------------------------------------------------
    readonly property int barHeight: 64
    readonly property int pillTop: 20          // margin-top of every module
    readonly property int pillHeight: barHeight - pillTop
    readonly property int pillRadius: 10
    readonly property int pillBorder: 2
    readonly property int pillPadding: 10      // padding: 0 10px
    readonly property int groupGap: 10         // margin between joined groups
    readonly property int edgeGap: 20          // arch margin-left / modules-right padding-right

    // ---- opacity (user decision 2026-11-09: background only; may flip back) -------------
    // Waybar look: pillOpacity 0.8 AND contentOpacity 0.8 (whole module translucent).
    readonly property real pillOpacity: 0.8    // pill background + border
    readonly property real contentOpacity: 1.0 // text and icons

    // ---- font ---------------------------------------------------------------------------
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 16

    // ---- animation ----------------------------------------------------------------------
    readonly property int animFast: 150
    readonly property int animNormal: 250
    readonly property int animSlow: 400

    // ---- workspaces (user decision 2026-11-09: pywal, not Waybar's hardcoded colours) ---
    readonly property color wsInactive: color8       // was #4a4b66
    readonly property color wsActive: foreground     // was #a6adc8
    readonly property color wsPill: Qt.rgba(color5.r, color5.g, color5.b, 0.35) // sliding focus pill
    readonly property color wsUrgentBg: color2
    readonly property color wsUrgentFg: color0

    // ---- hardcoded Waybar colours (not pywal) -------------------------------------------

    readonly property color calMonth: "#ffead3"
    readonly property color calDays: "#ecc6d9"
    readonly property color calWeeks: "#99ffdd"
    readonly property color calWeekdays: "#ffcc66"
    readonly property color calToday: "#ff6699"

    readonly property color progressFill: Qt.rgba(110 / 255, 115 / 255, 141 / 255, 0.3)
    readonly property color progressTrack: Qt.rgba(54 / 255, 58 / 255, 79 / 255, 0.3)
}
