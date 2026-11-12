import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.components

// Left group [arch | clock] (Waybar custom/arch + clock).
// - arch: tooltip = a pfetch preview in the terminal's (pywal) colours (no hint line, user
//   2026-11-11). Left click opens fastfetch in a floating kitty (sized by Hyprland's 16:10
//   `floating` rule) that closes on any key. pfetch runs
//   only when the pointer enters the arch pill (the tooltip shows 400 ms later), never in the
//   background; its output is kept while the tooltip stays open and refreshed on the next hover.
// - clock: tooltip = the month calendar (CalendarView). While it is shown, scrolling on the clock
//   changes the month (up = previous, down = next); it resets when the tooltip closes.
PillGroup {
    id: root

    property alias clockSegment: clock
    property int monthOffset: 0
    // Was (Waybar): "pkill wofi || ~/.dotfiles/scripts/system_menu.sh --menu", with the tooltip
    // hint "Open System Menu". Replaced on 2026-11-11 by fastfetch (user request).
    // `-o font_size=11`: one kitty font step (2pt) below the 13pt default (user 2026-11-11).
    // Run.floating() puts these kitty options after `--class floating`, before the program.
    readonly property string archCommand: "-o font_size=11 bash -c 'fastfetch; read -rsn1'"

    // ---- calendar scroll (user feedback 2026-11-11: less sensitive) ----------------------
    // One month needs `wheelStep` accumulated angleDelta (2 mouse-wheel notches, or the same
    // distance on a touchpad). After a month change, input is ignored (and dropped) for
    // `wheelCooldownMs`, so a fast flick moves one or two months instead of ten. A half-done
    // step is forgotten after `wheelIdleMs` without scrolling, or when the direction flips.
    readonly property int wheelStep: 240
    readonly property int wheelCooldownMs: 250
    readonly property int wheelIdleMs: 1000
    property real _wheelAcc: 0
    property real _wheelLastAt: -1e9
    property real _wheelStepAt: -1e9

    // Feeds one wheel delta (> 0 = up) at time `t` (ms). Returns the month change (-1, 0, 1).
    function wheelMonths(delta: real, t: real): int {
        if (delta === 0)
            return 0;
        const idle = t - _wheelLastAt > wheelIdleMs;
        _wheelLastAt = t;
        if (t - _wheelStepAt < wheelCooldownMs) {
            _wheelAcc = 0;
            return 0;
        }
        if (idle || (_wheelAcc !== 0 && Math.sign(_wheelAcc) !== Math.sign(delta)))
            _wheelAcc = 0;
        _wheelAcc += delta;
        if (Math.abs(_wheelAcc) < wheelStep)
            return 0;
        const step = _wheelAcc > 0 ? -1 : 1;   // up = previous month
        _wheelAcc = 0;
        _wheelStepAt = t;
        monthOffset += step;
        return step;
    }

    // ---- pfetch preview -----------------------------------------------------------------
    property string pfetchRaw: ""   // last output, with ANSI colour codes
    // StyledText version; re-coloured live when the pywal palette changes.
    readonly property string pfetchHtml: ansiToStyled(pfetchRaw, Theme.wal)

    // ANSI colour n (0..15) -> pywal colour, like the terminal (kitty uses the pywal palette).
    function ansiColor(n: int, wal: var): string {
        const c = wal?.colors?.["color" + n];
        return c ? String(c).toLowerCase() : String(Theme.foreground);
    }

    function _xterm256(n: int, wal: var): string {
        if (n < 16)
            return ansiColor(n, wal);
        const hex = v => v.toString(16).padStart(2, "0");
        if (n >= 232) {
            const g = 8 + (n - 232) * 10;
            return "#" + hex(g) + hex(g) + hex(g);
        }
        const i = n - 16;
        const lvl = v => v === 0 ? 0 : 55 + v * 40;
        return "#" + hex(lvl(Math.floor(i / 36))) + hex(lvl(Math.floor(i / 6) % 6)) + hex(lvl(i % 6));
    }

    // Applies one SGR sequence ("1;36") to the current colour (null = default text colour).
    function _sgr(params: string, color: var, wal: var): var {
        const p = params === "" ? [0] : params.split(";").map(x => parseInt(x) || 0);
        for (let i = 0; i < p.length; i++) {
            const v = p[i];
            if (v === 0 || v === 39)
                color = null;
            else if (v >= 30 && v <= 37)
                color = ansiColor(v - 30, wal);
            else if (v >= 90 && v <= 97)
                color = ansiColor(v - 90 + 8, wal);
            else if (v === 38 && p[i + 1] === 5 && i + 2 < p.length) {
                color = _xterm256(p[i + 2], wal);
                i += 2;
            } else if (v === 38 && p[i + 1] === 2 && i + 4 < p.length) {
                color = Qt.rgba(p[i + 2] / 255, p[i + 3] / 255, p[i + 4] / 255, 1).toString();
                i += 4;
            } else if (v === 38 || v === 48) {
                break;   // malformed extended colour: ignore the rest
            }
            // Bold (1), backgrounds etc. are ignored: the tooltip font is bold anyway.
        }
        return color;
    }

    // Terminal output with ANSI colours -> Text.StyledText. Spaces become &nbsp; (StyledText
    // collapses whitespace) so the monospace logo keeps its shape; lines are joined with <br>.
    function ansiToStyled(raw: string, wal: var): string {
        if (raw === "")
            return "";
        const escape = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;").replace(/ /g, "&nbsp;");
        const lines = raw.replace(/\r/g, "").replace(/\t/g, "    ").replace(/\s+$/, "").split("\n");
        const out = [];
        let color = null;   // carries over line ends, like a terminal
        for (let line of lines) {
            // Trailing spaces (logo padding without info text) would only widen the box.
            line = line.replace(/ +((?:\x1b\[[0-9;?]*[A-Za-z])*)$/, "$1");
            let html = "";
            const emit = txt => {
                if (txt !== "")
                    html += color ? "<font color=\"" + color + "\">" + escape(txt) + "</font>" : escape(txt);
            };
            const re = /\x1b\[([0-9;?]*)([A-Za-z])/g;
            let last = 0;
            let m;
            while ((m = re.exec(line)) !== null) {
                emit(line.slice(last, m.index));
                last = re.lastIndex;
                if (m[2] === "m" && m[1].indexOf("?") < 0)
                    color = _sgr(m[1], color, wal);
            }
            emit(line.slice(last).replace(/\x1b/g, ""));
            out.push(html);
        }
        return out.join("<br>");
    }

    // Runs pfetch again (the arch pill calls this on hover).
    function refreshPfetch(): void {
        pfetchProc.running = true;
    }

    Process {
        id: pfetchProc
        // --color: pfetch prints no colours when stdout isn't a tty.
        command: ["pfetch", "--color"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    root.pfetchRaw = this.text;
            }
        }
    }

    // custom/arch: system menu launcher.
    Segment {
        id: arch

        readonly property bool tooltipShown: TooltipState.active && TooltipState.target === arch

        rightPadding: 15
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                Run.floating(root.archCommand);
        }

        // Refresh pfetch when the pointer enters, unless this tooltip is still open (hanging).
        onHoveredChanged: {
            if (hovered && !tooltipShown)
                root.refreshPfetch();
        }

        tooltipComponent: Component {
            // Extra space above and below the pfetch block (user 2026-11-11): 6px on top of the
            // tooltip box's own 8px padding, so 14px in total.
            Item {
                readonly property int extra: 6
                implicitWidth: pfetchText.implicitWidth
                implicitHeight: pfetchText.implicitHeight + 2 * extra

                BarText {
                    id: pfetchText
                    y: parent.extra
                    textFormat: Text.StyledText
                    text: root.pfetchHtml
                }
            }
        }

        BarText {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.color4
            text: ""
        }
    }

    // clock: Waybar format "<b> {:%R  %a,%e. %b}</b>" (BarText is already bold).
    Segment {
        id: clock

        readonly property bool calendarShown: TooltipState.active && TooltipState.target === clock

        tooltipComponent: Component {
            CalendarView {
                monthOffset: root.monthOffset
            }
        }

        onScrolled: wheel => {
            if (!clock.calendarShown)
                return;
            const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y * 8;
            root.wheelMonths(d, Date.now());
        }

        // Back to the current month when the calendar closes (or the tooltip glides elsewhere).
        Connections {
            target: TooltipState
            function onRevisionChanged() {
                if (!clock.calendarShown) {
                    root.monthOffset = 0;
                    root._wheelAcc = 0;
                }
            }
        }

        SystemClock {
            id: sysClock
            precision: SystemClock.Minutes
        }

        // C locale, so weekday and month names are English like Waybar.
        readonly property var cLocale: Qt.locale("C")
        // Always ", " + the day without padding: "Mon, 9." and "Wed, 11.". Waybar's %e padded to two
        // characters, so two-digit days had no space after the comma (user 2026-11-11).
        readonly property string dayText: String(sysClock.date.getDate())

        BarText {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.color3
            text: " " + sysClock.date.toLocaleString(clock.cLocale, "HH:mm")
                + "  " + sysClock.date.toLocaleString(clock.cLocale, "ddd") + ", " + clock.dayText
                + ". " + sysClock.date.toLocaleString(clock.cLocale, "MMM")
        }
    }
}
