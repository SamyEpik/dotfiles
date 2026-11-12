import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import qs
import qs.components

// [network | bluetooth]: replaces Waybar's `network` and `bluetooth` modules.
// Both pills show one icon only (user decision 2026-11-11); the numbers live in the tooltips
// (InfoTable). Event-driven: state, SSID and signal come from Quickshell.Networking
// (NetworkManager), adapter and devices from Quickshell.Bluetooth (BlueZ). Only the gaps are
// filled by read-only commands, run on change (never polled):
//  - IP/CIDR: `nmcli -g IP4.ADDRESS,IP6.ADDRESS dev show <if>` (device/state change, hover)
//  - controller MAC: `busctl get-property org.bluez <adapter> org.bluez.Adapter1 Address`
// Bandwidth (tooltip) = /proc/net/dev deltas, sampled only while the network pill is hovered.
PillGroup {
    id: root

    // For the shell / test harnesses (e.g. TooltipState.request(netSegment, "", netSegment.tooltipComponent)).
    readonly property Item netSegment: netSeg
    readonly property Item btSegment: btSeg

    // ---- glyphs ---------------------------------------------------------------------
    // Click hints (copied from config.jsonc).
    readonly property string mouseIcon: String.fromCodePoint(0xf037d)     // 󰍽
    readonly property string leftHint: "\ue352" + mouseIcon               // left click
    readonly property string rightHint: mouseIcon + "\ue37f"              // right click

    // Material Design icons (JetBrainsMono Nerd Font, names checked in the font's cmap).
    readonly property var wifiStrength: [                                 // md-wifi_strength_*
        0xf092f, 0xf091f, 0xf0922, 0xf0925, 0xf0928]                      //   outline, 1..4
    readonly property var wifiStrengthAlert: [                            // md-wifi_strength_*_alert
        0xf092b, 0xf0920, 0xf0923, 0xf0926, 0xf0929]                      //   alert_outline, 1..4
    readonly property int icWifiOff: 0xf092e        // md-wifi_strength_off_outline (unused: drawn instead)
    // User choice 2026-11-11: line-style wifi. Levels/disconnected are drawn (components/WifiIcon.qml);
    // disabled and linked-without-IP use the matching line-style alert glyph.
    readonly property int icWifiDisabled: 0xf16b5   // md-wifi_alert (line style)
    readonly property int icEthernet: 0xf0200       // md-ethernet (Waybar's icon)
    readonly property int icEthernetNoIp: 0xf031a   // md-lan_pending
    readonly property int icEthernetOff: 0xf0202    // md-ethernet_cable_off
    readonly property var btBattery: [              // md-battery_{10..90}_bluetooth, md-battery_bluetooth
        0xf093e, 0xf093f, 0xf0940, 0xf0941, 0xf0942, 0xf0943, 0xf0944, 0xf0945, 0xf0946, 0xf0948]
    readonly property int icBtBatteryEmpty: 0xf0947 // md-battery_alert_bluetooth (< 5%)
    readonly property int icBtHeadphones: 0xf0970   // md-headphones_bluetooth
    readonly property int icBtSpeaker: 0xf09a2      // md-speaker_bluetooth
    readonly property int icBtConnected: 0xf00b1    // md-bluetooth_connect
    readonly property int icBtIdle: 0xf00b2         // md-bluetooth_off (struck through)
    readonly property int icAlert: 0xf0026          // md-alert (the font has no bluetooth+alert icon)

    // ==== network ========================================================================
    readonly property var devs: Networking.devices.values
    readonly property var wifiDev: devs.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDev: devs.find(d => d.type === DeviceType.Wired) ?? null
    readonly property bool wiredUp: !!wiredDev && (wiredDev.connected || wiredDev.state === ConnectionState.Connected)
    readonly property bool wifiUp: !!wifiDev && (wifiDev.connected || wifiDev.state === ConnectionState.Connected)
    readonly property bool wiredLink: !!wiredDev && wiredDev.hasLink
    readonly property bool wifiLinking: !!wifiDev && wifiDev.state === ConnectionState.Connecting

    // The interface Waybar would follow (it uses the default route; wired wins on metric).
    readonly property var netDev: wiredUp ? wiredDev : wifiUp ? wifiDev : wiredLink ? wiredDev : wifiLinking ? wifiDev : null
    readonly property bool netIsWifi: !!netDev && netDev === wifiDev
    readonly property string ifname: netDev?.name ?? ""
    readonly property var wifiNet: netIsWifi ? (wifiDev.networks.values.find(n => n.connected) ?? null) : null
    readonly property string essid: wifiNet?.name ?? ""
    readonly property int signal: wifiNet ? Math.round(wifiNet.signalStrength * 100) : 0
    readonly property bool wifiDisabled: !Networking.wifiEnabled || !Networking.wifiHardwareEnabled

    // From nmcli, for `ifname` (empty until the first run finishes).
    property string ipaddr: ""
    property string cidr: ""
    property bool hasIp6: false
    // NM's "Connected" (activated) implies an IP config; it also avoids a "no IP" flash at startup
    // before nmcli has answered.
    readonly property bool hasIp: ipaddr !== "" || hasIp6 || (!!netDev && netDev.state === ConnectionState.Connected)

    // Waybar's state machine: no carrier -> disabled (rfkill) / disconnected; carrier but no
    // address -> linked; no ESSID -> ethernet; else wifi.
    readonly property string netState: !netDev ? (wifiDisabled ? "disabled" : "disconnected")
                                     : !hasIp ? "linked"
                                     : essid === "" && !netIsWifi ? "ethernet" : "wifi"

    // Signal % -> 0..4 bars (NetworkManager applet thresholds).
    function wifiBars(pct) {
        return pct > 80 ? 4 : pct > 55 ? 3 : pct > 30 ? 2 : pct > 5 ? 1 : 0;
    }

    // Pure, so the test harness can feed it any state.
    // state: wifi / ethernet / linked / disconnected / disabled
    function netIcon(state, pct, isWifi, hasWifiDev) {
        switch (state) {
        case "wifi":
            return String.fromCodePoint(wifiStrength[wifiBars(pct)]);
        case "ethernet":
            return String.fromCodePoint(icEthernet);
        case "linked":
            return String.fromCodePoint(isWifi ? icWifiDisabled : icEthernetNoIp);
        case "disabled":
            return String.fromCodePoint(icWifiDisabled);
        default:
            return String.fromCodePoint(hasWifiDev ? icWifiOff : icEthernetOff);
        }
    }

    readonly property string netGlyph: netIcon(netState, signal, netIsWifi, !!wifiDev)
    // Drawn line-style wifi for "wifi" (lit arcs = bars) and "disconnected" with a wifi device (slashed).
    readonly property bool netDrawn: netState === "wifi" || (netState === "disconnected" && !!wifiDev)

    // Bandwidth in bytes/s (-1 = no sample yet).
    property real upRate: -1
    property real downRate: -1
    property var _lastSample: null

    // Fixed width (10 chars, monospace) so the tooltip never changes size: "  12.3 kB/s".
    function rateText(v) {
        if (v < 0)
            return "    \u2013     ";
        const units = ["B/s", "kB/s", "MB/s", "GB/s"];
        let p = 0;
        while (v >= 999.95 && p < units.length - 1) {
            v /= 1000;
            p++;
        }
        return v.toFixed(1).padStart(5) + " " + units[p].padStart(4);
    }

    readonly property var netHints: ["Open NetworkManager TUI: " + leftHint, "Open Network Usage: " + rightHint]
    readonly property var netRows: {
        const rates = [null, ["Upload", rateText(upRate)], ["Download", rateText(downRate)]];
        const addr = ipaddr !== "" ? ipaddr + "/" + cidr : hasIp6 ? "IPv6 only" : "\u2013";
        switch (netState) {
        case "wifi":
            return [["Network", essid], ["Signal", String(signal).padStart(3) + "%"], ["Address", addr], ["Interface", ifname]].concat(rates);
        case "ethernet":
            return [["Network", "Ethernet"], ["Address", addr], ["Interface", ifname]].concat(rates);
        case "linked":
            return [["Network", essid !== "" ? essid : netIsWifi ? "Wi-Fi" : "Ethernet"], ["Address", "No IP"], ["Interface", ifname]];
        case "disabled":
            return [["Network", "Wi-Fi disabled"]];
        default:
            return [["Network", "Disconnected"]];
        }
    }

    function refreshIp() {
        if (ifname === "") {
            ipaddr = "";
            cidr = "";
            hasIp6 = false;
            return;
        }
        ipProc.ifname = ifname;
        ipProc.running = false;
        ipProc.running = true;
    }

    onIfnameChanged: refreshIp()
    Connections {
        target: root.netDev
        ignoreUnknownSignals: true
        function onStateChanged() { root.refreshIp(); }
        function onConnectedChanged() { root.refreshIp(); }
    }
    Component.onCompleted: {
        refreshIp();
        refreshController();
    }

    Process {
        id: ipProc
        property string ifname: ""
        command: ["nmcli", "-g", "IP4.ADDRESS,IP6.ADDRESS", "dev", "show", ifname]
        stdout: StdioCollector {
            onStreamFinished: {
                if (ipProc.ifname !== root.ifname)
                    return; // stale answer for an older interface
                const lines = this.text.split("\n");
                const v4 = (lines[0] ?? "").split(" | ")[0].trim();
                const slash = v4.lastIndexOf("/");
                root.ipaddr = slash > 0 ? v4.slice(0, slash) : v4;
                root.cidr = slash > 0 ? v4.slice(slash + 1) : "";
                root.hasIp6 = (lines[1] ?? "").trim() !== "";
            }
        }
    }

    // /proc/net/dev is read only while the network pill is hovered.
    FileView {
        id: netDevFile
        path: "/proc/net/dev"
        blockLoading: true
    }

    function sampleBandwidth() {
        netDevFile.reload();
        const line = netDevFile.text().split("\n").find(l => l.trim().startsWith(ifname + ":"));
        if (!line) {
            upRate = downRate = -1;
            _lastSample = null;
            return;
        }
        const f = line.split(":")[1].trim().split(/\s+/);
        const s = { t: Date.now(), rx: Number(f[0]), tx: Number(f[8]), ifname: ifname };
        const l = _lastSample;
        if (l && l.ifname === s.ifname && s.t > l.t) {
            const dt = (s.t - l.t) / 1000;
            downRate = Math.max(0, (s.rx - l.rx) / dt);
            upRate = Math.max(0, (s.tx - l.tx) / dt);
        }
        _lastSample = s;
    }

    Timer {
        // First delta after 700 ms so the tooltip fills quickly, then every 2 s.
        interval: root.upRate < 0 ? 700 : 2000
        repeat: true
        triggeredOnStart: true
        running: netSeg.hovered && root.ifname !== ""
        onTriggered: root.sampleBandwidth()
        onRunningChanged: {
            if (!running) {
                root._lastSample = null;
                root.upRate = root.downRate = -1;
            }
        }
    }

    // ==== bluetooth ======================================================================
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btConnected: adapter ? adapter.devices.values.filter(d => d.connected) : []
    readonly property var btBatteryDev: btConnected.find(d => d.batteryAvailable) ?? null
    readonly property var btAudioDev: btConnected.find(d => isAudio(d.icon)) ?? null
    // The device the pill shows: one with a battery first, then audio, then any.
    readonly property var btMainDev: btBatteryDev ?? btAudioDev ?? btConnected[0] ?? null
    property string controllerAddress: ""

    // Waybar {status}: no-controller / off / connected / on; "disabled" = rfkill blocked.
    readonly property string btState: !adapter ? "no-controller"
                                    : adapter.state === BluetoothAdapterState.Blocked ? "disabled"
                                    : !adapter.enabled ? "off"
                                    : btConnected.length > 0 ? "connected" : "on"

    function btPct(d) {
        return Math.round(d.battery * 100);
    }

    function isAudio(icon) {
        return (icon ?? "").startsWith("audio-");
    }

    // Pure, so the test harness can feed it any state. dev: { batteryAvailable, battery, icon }.
    function btIcon(state, dev) {
        if (state === "on")
            return String.fromCodePoint(icBtIdle);
        if (state !== "connected" || !dev)
            return String.fromCodePoint(icAlert);   // off, disabled (rfkill), no controller
        if (dev.batteryAvailable) {
            const pct = Math.round(dev.battery * 100);
            // < 5% alert, 5-14% -> 10, ..., 85-94% -> 90, >= 95% full.
            return String.fromCodePoint(pct < 5 ? icBtBatteryEmpty : btBattery[Math.min(10, Math.max(1, Math.round(pct / 10))) - 1]);
        }
        if (dev.icon === "audio-speakers")
            return String.fromCodePoint(icBtSpeaker);
        if (isAudio(dev.icon))
            return String.fromCodePoint(icBtHeadphones);
        return String.fromCodePoint(icBtConnected);
    }

    readonly property string btGlyph: btIcon(btState, btMainDev)
    // User choice 2026-11-11 ("B1"): audio devices without battery info show a full-size device
    // glyph with a small bluetooth badge (md-headphones_bluetooth is drawn too small).
    readonly property bool btBadged: btState === "connected" && !!btMainDev && !btMainDev.batteryAvailable
                                     && isAudio(btMainDev.icon)
    readonly property string btBadgeMain: String.fromCodePoint(btMainDev?.icon === "audio-speakers" ? 0xf04c3 : 0xf025) // md-speaker / fa-headphones

    readonly property var btHints: ["Open Bluetuith: " + leftHint]
    readonly property var btRows: {
        if (!adapter)
            return [["State", "No controller"]];
        const state = btState === "disabled" ? "Blocked (rfkill)"
                    : btState === "off" ? "Off"
                    : btConnected.length > 0 ? btConnected.length + " connected"
                    : "On, nothing connected";
        const rows = [["Controller", adapter.name], ["Address", controllerAddress], ["State", state]];
        if (btConnected.length === 0)
            return rows;
        return rows.concat([null], btConnected.map(d => [d.name, d.batteryAvailable ? String(btPct(d)).padStart(3) + "%" : d.address]));
    }

    onAdapterChanged: refreshController()
    function refreshController() {
        if (!adapter) {
            controllerAddress = "";
            return;
        }
        addrProc.path = adapter.dbusPath;
        addrProc.running = false;
        addrProc.running = true;
    }

    Process {
        id: addrProc
        property string path: ""
        command: ["busctl", "--system", "get-property", "org.bluez", path, "org.bluez.Adapter1", "Address"]
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim() !== "") console.warn("NetBt: busctl:", this.text.trim())
        }
        stdout: StdioCollector {
            // Output: s "E0:C9:32:23:F4:2D"
            onStreamFinished: {
                const m = this.text.match(/"([^"]*)"/);
                root.controllerAddress = m ? m[1] : "";
            }
        }
    }

    // ==== segments =======================================================================
    Segment {
        id: netSeg

        tooltipComponent: Component {
            InfoTable {
                hints: root.netHints
                rows: root.netRows
            }
        }
        onHoveredChanged: if (hovered) root.refreshIp()
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                Run.floating("nmtui");
            else if (mouse.button === Qt.RightButton)
                Run.floating("btop -p 4");
        }

        WifiIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.netDrawn
            color: Theme.readable(Theme.color3, 4.5)   // readable on the pill (user 2026-11-11)
            level: root.netState === "wifi" ? root.wifiBars(root.signal) : 0
            slashed: root.netState === "disconnected"
        }

        FancyText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.netDrawn
            color: Theme.readable(Theme.color3, 4.5)   // readable on the pill (user 2026-11-11)
            text: root.netGlyph
        }
    }

    Segment {
        id: btSeg

        tooltipComponent: Component {
            InfoTable {
                hints: root.btHints
                rows: root.btRows
            }
        }
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                Run.floating("bluetuith");
        }

        BadgeIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.btBadged
            color: Theme.readable(Theme.color4, 4.5)   // readable on the pill (user 2026-11-11)
            main: root.btBadgeMain
            badge: String.fromCodePoint(0xf00af) // md-bluetooth
        }

        FancyText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.btBadged
            color: Theme.readable(Theme.color4, 4.5)   // readable on the pill (user 2026-11-11)
            text: root.btGlyph
        }
    }
}
