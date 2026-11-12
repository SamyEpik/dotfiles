import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.components

// [volume | mic]: replaces Waybar's `pulseaudio` and `pulseaudio#microphone`.
// Event-driven through Pipewire (no wpctl polling). Volumes are on the cubic scale, the
// same as wpctl and Waybar. A segment hides while its node is missing or not ready.
PillGroup {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool sinkOk: !!(sink && sink.ready && sink.audio)
    readonly property bool sourceOk: !!(source && source.ready && source.audio)

    readonly property int sinkPct: sinkOk ? Math.round(sink.audio.volume * 100) : 0
    readonly property int sourcePct: sourceOk ? Math.round(source.audio.volume * 100) : 0
    readonly property bool sinkMuted: sinkOk && sink.audio.muted
    readonly property bool sourceMuted: sourceOk && source.audio.muted

    // Glyphs copied from config.jsonc (the ramp entries 2 and 3 carry a trailing space there).
    readonly property string mutedIcon: String.fromCodePoint(0xf075f)   // 󰝟
    readonly property string mouseIcon: String.fromCodePoint(0xf037d)   // 󰍽
    readonly property var formIcons: ({
            "headphone": "",
            "hands-free": "",
            "headset": "",
            "phone": "",
            "portable": "",
            "car": ""
        })
    readonly property var rampIcons: ["", " ", " "]
    // Waybar's port keywords, in its match order (pulseaudio.cpp).
    readonly property var ports: ["headphone", "speaker", "hdmi", "headset", "hands-free", "portable", "car", "hifi", "phone"]

    // Waybar matches the keywords against "<active port name><device form factor>". Pipewire
    // nodes don't expose the port or the device, so use what the node has: a form factor if
    // set, the UCM/ACP profile name ("HiFi: Headphones: sink"), and for Bluetooth the A2DP
    // "headphone" form factor (Waybar sees port "headphone-output" for the AirPods).
    function portKind(node) {
        if (!node)
            return "";
        const p = node.properties ?? {};
        let s = (p["device.form-factor"] ?? "") + " " + (p["device.profile.name"] ?? "");
        if (p["device.api"] === "bluez5" || (node.name ?? "").startsWith("bluez_output")) {
            const prof = p["api.bluez5.profile"] ?? "";
            s += prof.startsWith("headset") ? " headset" : " headphone";
        }
        s = s.toLowerCase();
        return ports.find(k => s.includes(k)) ?? "";
    }

    // Waybar ALabel::getIcon: idx = clamp(volume / (100 / size), 0, size - 1), integer maths.
    function rampIndex(pct) {
        const step = Math.floor(100 / rampIcons.length);
        return Math.max(0, Math.min(rampIcons.length - 1, Math.floor(pct / step)));
    }

    function sinkIcon(node, pct) {
        return formIcons[portKind(node)] ?? rampIcons[rampIndex(pct)];
    }

    // Inverted scroll like Waybar: steps > 0 = scroll down = 1% up per step (limit 1.0);
    // steps < 0 = scroll up = 1% down. Snaps to whole percent. Never raises above 1.0 and
    // never lowers a volume that is already above 1.0 when raising.
    function steppedVolume(cur, steps) {
        const target = (Math.round(cur * 100) + steps) / 100;
        if (steps > 0)
            return cur >= 1.0 ? cur : Math.min(1.0, target);
        return Math.max(0, target);
    }

    // Touchpads send small angleDeltas: accumulate to whole 120-unit notches.
    function applyWheel(wheel, acc, audio) {
        const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y * 8;
        if (d === 0)
            return acc;
        if (acc !== 0 && Math.sign(acc) !== Math.sign(d))
            acc = 0;
        acc += d;
        const notches = acc > 0 ? Math.floor(acc / 120) : Math.ceil(acc / 120);
        if (notches !== 0 && audio) {
            acc -= notches * 120;
            audio.volume = steppedVolume(audio.volume, -notches); // up (+) = volume down
        }
        return acc;
    }

    function desc(node) {
        return node ? (node.description || node.nickname || node.name) : "";
    }

    readonly property string sinkText: sinkMuted ? mutedIcon + " Muted" : sinkIcon(sink, sinkPct) + " " + sinkPct + "%"
    readonly property string sourceText: sourceMuted ? "  Muted" : " " + sourcePct + "%"

    visible: sinkOk || sourceOk

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    Segment {
        id: volumeSeg

        property real wheelAcc: 0

        visible: root.sinkOk
        // No volume row: the pill shows it (user: no duplicate info in pill and tooltip).
        tooltipComponent: Component {
            InfoTable {
                hints: ("Toggle Mute: " + root.mouseIcon + "\nOpen Wiremix Playback: " + root.mouseIcon + "").split("\n")
                rows: [["Output", root.desc(root.sink)]]
            }
        }
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                if (root.sinkOk)
                    root.sink.audio.muted = !root.sink.audio.muted;
            } else if (mouse.button === Qt.RightButton) {
                Run.floating("wiremix");
            }
        }
        onScrolled: wheel => wheelAcc = root.applyWheel(wheel, wheelAcc, root.sinkOk ? root.sink.audio : null)

        BarText {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.color4
            textFormat: Text.PlainText
            text: root.sinkText
        }
    }

    Segment {
        id: micSeg

        property real wheelAcc: 0

        visible: root.sourceOk
        tooltipComponent: Component {
            InfoTable {
                hints: ("Toggle Mute: " + root.mouseIcon + "\nOpen Wiremix Recording: " + root.mouseIcon + "").split("\n")
                rows: [["Input", root.desc(root.source)]]
            }
        }
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                if (root.sourceOk)
                    root.source.audio.muted = !root.source.audio.muted;
            } else if (mouse.button === Qt.RightButton) {
                Run.floating("wiremix --tab recording");
            }
        }
        onScrolled: wheel => wheelAcc = root.applyWheel(wheel, wheelAcc, root.sourceOk ? root.source.audio : null)

        BarText {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.color5
            textFormat: Text.PlainText
            text: root.sourceText
        }
    }
}
