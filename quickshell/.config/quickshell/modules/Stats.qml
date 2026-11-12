import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs
import qs.components

// [cputemp | memory | battery]: replaces Waybar's `custom/cputemp` (scripts/cpu_temp.sh),
// `memory` and `battery`.
//  - cputemp: coretemp package temp + CPU usage from /proc/stat deltas, every 2 s.
//  - memory:  /proc/meminfo every 5 s, Waybar maths (used = MemTotal - MemAvailable).
//  - battery: UPower displayDevice (event-driven). Health, cycles, design capacity, type and the
//             charge limit come from sysfs, read at startup and whenever the battery pill is
//             hovered (no polling).
//  - top process (cpu and memory tooltips): one awk pass over /proc/[pid]/stat, run only while one
//             of those tooltips is shown (on open, after 0.5 s, then every 2 s). CPU % is the
//             utime+stime delta between two samples, per core like the user's btop
//             (proc_per_core = true) and top; memory is the largest RSS.
//  - CPU frequency (cpu tooltip): mean of the "cpu MHz" lines in /proc/cpuinfo, read on the same
//             timer as the top process and only while the cpu tooltip is shown. With intel_pstate
//             on kernel 7.x, /proc/cpuinfo and cpufreq/scaling_cur_freq both report the same
//             APERF/MPERF average (arch_freq_get_on_cpu), so they are equally accurate; cpuinfo is
//             one in-process FileView read instead of 16 files or a fork.
// Tooltips are InfoTables and never repeat what the pill shows (round 3 user rule).
// The formatting is in pure functions (batteryView, memRows, ...) so it can be tested with
// simulated values.
PillGroup {
    id: root

    // ---- glyphs (copied from config.jsonc / cpu_temp.sh) ---------------------------------
    readonly property string mouseIcon: String.fromCodePoint(0xf037d)  // 󰍽
    readonly property string leftClick: "" + mouseIcon           // Waybar's left-click hint
    readonly property string thermoIcon: ""                      //
    readonly property string memIcon: ""                         //
    readonly property string plugIcon: ""                        //  (charging and plugged)
    readonly property var batteryIcons: [0xf008e, 0xf007a, 0xf007b, 0xf007c, 0xf007d, 0xf007e,
        0xf007f, 0xf0080, 0xf0081, 0xf0082, 0xf0079].map(c => String.fromCodePoint(c))

    // ---- shared fixed-width formatting (the font is monospace) --------------------------
    readonly property int nameWidth: 15   // kernel comm is at most 15 chars (kworkers are longer)

    function fmtName(n) {
        const s = String(n);
        return (s.length > nameWidth ? s.slice(0, nameWidth - 1) + "…" : s).padEnd(nameWidth);
    }

    // Per-core %: "12.3%", " 104%", "1600%" (always 5 chars).
    function fmtPct(v) {
        return (v < 99.95 ? v.toFixed(1) : String(Math.round(v))).padStart(4) + "%";
    }

    // Bytes: "1.23 GiB", "12.3 GiB", " 512 MiB" (always 8 chars).
    function fmtBytes(b) {
        const g = b / 1073741824;
        const s = g >= 9.995 ? g.toFixed(1) + " GiB" : g >= 0.9995 ? g.toFixed(2) + " GiB" : Math.round(b / 1048576) + " MiB";
        return s.padStart(8);
    }

    // ======================================================================================
    // cputemp
    // ======================================================================================
    readonly property int criticalTemp: 80
    property string tempPath: ""   // resolved once: the hwmon number changes between boots
    property int temp: 0           // °C, truncated like the script's $((x / 1000))
    property int cpuUsage: 0       // %
    property var _prevCpu: null    // { idle, total } of the previous /proc/stat sample
    readonly property bool tempCritical: temp >= criticalTemp

    // First line of /proc/stat: "cpu user nice system idle iowait irq softirq steal guest ..."
    function parseCpu(statText) {
        const f = statText.split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
        if (f.length < 8 || f.some(isNaN))
            return null;
        return { idle: f[3] + f[4], total: f.reduce((a, b) => a + b, 0) };
    }

    // Same rounding as cpu_temp.sh: (100 * busy + total / 2) / total, integer maths.
    function cpuPercent(prev, cur) {
        const dTotal = cur.total - prev.total;
        const dIdle = cur.idle - prev.idle;
        return dTotal > 0 ? Math.floor((100 * (dTotal - dIdle) + Math.floor(dTotal / 2)) / dTotal) : 0;
    }

    // The pill shows the temperature, so the tooltip shows usage, frequency and the top process.
    function cpuRows(usage, mhz, top) {
        return [
            ["CPU usage", String(usage).padStart(3) + "%"],
            ["Frequency", fmtMhz(mhz)],
            ["Top process", top ? fmtName(top.name) + " " + fmtPct(top.pct) : fmtName("measuring…") + " " + "–".padStart(4) + "%"]
        ];
    }

    // " 400 MHz", "2345 MHz", "   – MHz" until the first sample (always 8 chars below 10 GHz).
    function fmtMhz(mhz) {
        return (mhz > 0 ? String(Math.round(mhz)) : "–").padStart(4) + " MHz";
    }

    // Mean of all "cpu MHz : 1234.567" lines; 0 if there are none.
    function parseCpuMhz(txt) {
        const v = [];
        for (const line of txt.split("\n")) {
            const r = /^cpu MHz\s*:\s*([\d.]+)/.exec(line);
            if (r)
                v.push(Number(r[1]));
        }
        return v.length > 0 ? v.reduce((a, b) => a + b, 0) / v.length : 0;
    }

    Process {
        running: true
        command: ["sh", "-c", "ls /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: root.tempPath = this.text.trim()
        }
    }

    FileView {
        id: tempFile
        path: root.tempPath
        printErrors: false
        onLoaded: {
            const v = parseInt(text());
            if (!isNaN(v))
                root.temp = Math.trunc(v / 1000);
        }
    }

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: {
            const cur = root.parseCpu(text());
            if (!cur)
                return;
            if (root._prevCpu)
                root.cpuUsage = root.cpuPercent(root._prevCpu, cur);
            root._prevCpu = cur;
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            statFile.reload();
            if (root.tempPath !== "")
                tempFile.reload();
        }
    }

    // ======================================================================================
    // memory
    // ======================================================================================
    property var mem: ({ total: 0, avail: 0, swapTotal: 0, swapFree: 0 }) // kB

    function parseMeminfo(txt) {
        const m = {};
        for (const line of txt.split("\n")) {
            const r = /^(\w+):\s+(\d+)/.exec(line);
            if (r)
                m[r[1]] = Number(r[2]);
        }
        // Waybar: MemAvailable on kernels >= 3.4, else free + buffers + cached + reclaimable - shmem.
        const avail = m.MemAvailable ?? ((m.MemFree ?? 0) + (m.Buffers ?? 0) + (m.Cached ?? 0) + (m.SReclaimable ?? 0) - (m.Shmem ?? 0));
        return { total: m.MemTotal ?? 0, avail: avail, swapTotal: m.SwapTotal ?? 0, swapFree: m.SwapFree ?? 0 };
    }

    // Waybar: int used_ram_percentage = 100 * (memtotal - memfree) / memtotal (truncated).
    function memPercent(m) {
        return m.total > 0 ? Math.floor(100 * (m.total - m.avail) / m.total) : 0;
    }

    function gib(kb) {
        return (kb / (1024 * 1024)).toFixed(1); // Waybar's G = kB / 1024^2 (GiB)
    }

    // The pill shows the used %, so the tooltip shows amounts and the top process.
    function memRows(m, top) {
        const rows = [["Memory", gib(m.total - m.avail).padStart(4) + " / " + gib(m.total) + " GiB"]];
        if (m.swapTotal > 0)
            rows.push(["Swap", gib(m.swapTotal - m.swapFree).padStart(4) + " / " + gib(m.swapTotal) + " GiB"]);
        rows.push(["Top process", top ? fmtName(top.name) + " " + fmtBytes(top.rss) : fmtName("measuring…") + " " + "–".padStart(8)]);
        return rows;
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: root.mem = root.parseMeminfo(text())
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: memFile.reload()
    }

    // ======================================================================================
    // top process (only while the cpu or memory tooltip is shown)
    // ======================================================================================
    // Straight from TooltipState (not cpuShown || memShown), so gliding cpu -> memory never
    // passes through a transient `false` that would reset the samples.
    readonly property bool sampling: TooltipState.active && (TooltipState.target === tempSeg || TooltipState.target === memSeg)
    readonly property bool cpuShown: TooltipState.active && TooltipState.target === tempSeg

    property real cpuMhz: 0   // mean over all logical CPUs, 0 = not sampled yet

    // Path only set while the cpu tooltip is shown: setting it loads once, the sampler timer reloads.
    FileView {
        id: cpuinfoFile
        path: root.cpuShown ? "/proc/cpuinfo" : ""
        printErrors: false
        onLoaded: {
            const v = root.parseCpuMhz(text());
            if (v > 0)
                root.cpuMhz = v;
        }
    }

    property var _prevSample: null
    property var topCpu: null   // { name, pct }
    property var topMem: null   // { name, rss (bytes) }

    // One pass over /proc: "T <total jiffies, all cpus>", "N <cpu count>" and per process
    // "<pid> <utime+stime> <rss bytes> <comm>". The comm is taken between the first "(" and the
    // last ") " (it may contain spaces and parentheses). cat feeds awk because a process that
    // exits mid-read is a fatal read error in gawk but only a warning in cat. The sampler's own
    // sh/cat/awk are new in every sample, so topByCpu skips them.
    readonly property string sampleScript: "{ cat /proc/stat; cat /proc/[0-9]*/stat; } 2>/dev/null"
        + " | awk -v pg=$(getconf PAGESIZE) '"
        + "$1==\"cpu\" { t=0; for (i=2;i<=9;i++) t+=$i; print \"T\", t; next }"
        + " $1 ~ /^cpu[0-9]/ { n++; next }"
        + " $1 ~ /^[0-9]+$/ && index($0,\"(\") { o=index($0,\"(\"); c=$0; sub(/.*\\) /,\"\",c); split(c,f,\" \");"
        + " print $1, f[12]+f[13], f[22]*pg, substr($0,o+1,length($0)-length(c)-o-2) }"
        + " END { print \"N\", n }'"

    function parseSample(txt) {
        const s = { total: 0, ncpu: 0, procs: {} };
        for (const line of txt.split("\n")) {
            const r = /^(\S+) (\S+) (\S+) (.*)$/.exec(line);
            if (r) {
                s.procs[r[1]] = { t: Number(r[2]), rss: Number(r[3]), name: r[4] };
            } else {
                const k = /^([TN]) (\d+)$/.exec(line);
                if (k && k[1] === "T")
                    s.total = Number(k[2]);
                else if (k)
                    s.ncpu = Number(k[2]);
            }
        }
        return s;
    }

    // Busiest process between two samples, in % of one core. Processes that are new (or whose pid
    // was reused) in `cur` are skipped: their time can't be split by window.
    function topByCpu(prev, cur) {
        const perCore = (cur.total - prev.total) / cur.ncpu;
        if (perCore <= 0)
            return null;
        let best = null;
        let bestD = -1;
        for (const pid in cur.procs) {
            const c = cur.procs[pid];
            const p = prev.procs[pid];
            if (!p || p.name !== c.name)
                continue;
            const d = c.t - p.t;
            if (d > bestD) {
                bestD = d;
                best = c.name;
            }
        }
        return best === null ? null : { name: best, pct: 100 * bestD / perCore };
    }

    function topByMem(cur) {
        let best = null;
        for (const pid in cur.procs) {
            const c = cur.procs[pid];
            if (!best || c.rss > best.rss)
                best = { name: c.name, rss: c.rss };
        }
        return best;
    }

    onSamplingChanged: if (!sampling) Qt.callLater(resetSamples)

    function resetSamples() {
        if (sampling)
            return;
        _prevSample = null;
        topCpu = null;
        topMem = null;
        cpuMhz = 0;
    }

    Process {
        id: sampler
        command: ["sh", "-c", root.sampleScript]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.sampling)
                    return;
                const cur = root.parseSample(this.text);
                if (cur.total <= 0 || cur.ncpu <= 0)
                    return;
                root.topMem = root.topByMem(cur);
                if (root._prevSample)
                    root.topCpu = root.topByCpu(root._prevSample, cur);
                root._prevSample = cur;
            }
        }
    }

    Timer {
        running: root.sampling
        interval: root.topCpu ? 2000 : 500  // quick first CPU value (0.5 s window), then 2 s windows
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!sampler.running)
                sampler.running = true;
            if (root.cpuShown && cpuinfoFile.path !== "")
                cpuinfoFile.reload();
        }
    }

    // ======================================================================================
    // battery
    // ======================================================================================
    readonly property var bat: UPower.displayDevice
    readonly property bool batOk: !!(bat && bat.ready && bat.isLaptopBattery && bat.isPresent)
    // A real battery device, for its sysfs directory (the display device has no nativePath).
    readonly property var batDevice: UPower.devices.values.find(d => d.isLaptopBattery && d.nativePath !== "") ?? null
    readonly property string sysfsDir: batDevice ? "/sys/class/power_supply/" + batDevice.nativePath + "/" : ""

    property var uevent: ({})          // POWER_SUPPLY_* from sysfs uevent
    property int startThreshold: -1   // charge_control_*_threshold, -1 = not available
    property int endThreshold: -1

    function parseUevent(txt) {
        const u = {};
        for (const line of txt.split("\n")) {
            const i = line.indexOf("=");
            if (i > 0 && line.startsWith("POWER_SUPPLY_"))
                u[line.slice(13, i)] = line.slice(i + 1).trim();
        }
        return u;
    }

    // Battery condition from sysfs: energy_* in µWh, or charge_* in µAh (then Wh via the design voltage).
    function sysfsInfo(u) {
        const n = k => Number(u[k]) || 0;
        let full = n("ENERGY_FULL"), design = n("ENERGY_FULL_DESIGN"), designWh = design / 1e6;
        if (design <= 0) {
            full = n("CHARGE_FULL");
            design = n("CHARGE_FULL_DESIGN");
            designWh = design * n("VOLTAGE_MIN_DESIGN") / 1e12;
        }
        const cycles = u.CYCLE_COUNT !== undefined && n("CYCLE_COUNT") >= 0 ? String(n("CYCLE_COUNT")) : "";
        const kind = [u.MANUFACTURER ?? "", u.TECHNOLOGY ?? ""].filter(s => s !== "" && s !== "Unknown").join(" ");
        return {
            health: design > 0 && full > 0 ? 100 * full / design : NaN,
            designWh: designWh,
            cycles: cycles,
            kind: kind.length > 20 ? kind.slice(0, 19) + "…" : kind
        };
    }

    readonly property var sysInfo: sysfsInfo(uevent)
    readonly property string health: !isNaN(sysInfo.health) ? healthString(sysInfo.health)
        : (batDevice?.healthSupported ? healthString(batDevice.healthPercentage) : "")
    readonly property string chargeLimit: endThreshold < 0 ? ""
        : endThreshold >= 100 ? "off"
        : (startThreshold > 0 ? startThreshold + "–" : "") + endThreshold + "%"

    // Waybar formats health with fmt "{:.3}": 3 significant digits, trailing zeros dropped.
    function healthString(h) {
        return String(Number(Number(h).toPrecision(3)));
    }

    // Waybar's "{H} h {M} min", minutes zero-padded so the width only changes with the hours;
    // "" when both are 0.
    function formatTime(secs) {
        const hours = Math.abs(secs) / 3600;
        const h = Math.floor(hours);
        const m = Math.floor(60 * (hours - h));
        return (h === 0 && m === 0) ? "" : (h + " h " + String(m).padStart(2, "0") + " min").padStart(11);
    }

    // Waybar ALabel::getIcon: idx = clamp(capacity / (100 / size), 0, size - 1), integer maths.
    function batteryIcon(cap) {
        const step = Math.floor(100 / batteryIcons.length);
        return batteryIcons[Math.max(0, Math.min(batteryIcons.length - 1, Math.floor(cap / step)))];
    }

    function wh(v) {
        return v.toFixed(1).padStart(4);
    }

    // Everything the battery segment shows, from plain values (so it can be tested with fakes).
    //   s = { pct (0..1), state (UPowerDeviceState), onBattery, timeToEmpty, timeToFull (s),
    //         changeRate (W), energy, energyFull (Wh), designWh, health (string), cycles (string),
    //         limit (string), kind (string), performance (string, optional) }
    // Rows with missing data are left out. No capacity row: the pill shows it.
    function batteryView(s) {
        const cap = Math.min(100, Math.round(s.pct * 100));
        const charging = s.state === UPowerDeviceState.Charging;
        const plugged = !charging && !s.onBattery;      // on AC, not charging (full, threshold, ...)
        const discharging = !charging && s.onBattery;

        // Waybar: format-charging / format-plugged win over format.
        const text = (charging || plugged ? plugIcon : batteryIcon(cap)) + " " + cap + "%";

        const now = [];
        const cond = [];
        const add = (list, label, value) => {
            if (value !== undefined && value !== null && value !== "")
                list.push([label, value]);
        };

        // Placeholder (user decision 2026-11-11): will come from the power settings, e.g.
        // PowerProfiles.profile (Quickshell.Services.UPower, power-profiles-daemon). Not wired yet.
        add(now, "Performance", s.performance ?? "normal");

        // User decision 2026-11-11: the time and power rows are always shown ("Full" or "–" when
        // they don't apply), and nothing after them (energy, health, cycles, design capacity,
        // charge limit and type were too much). The sysfs data for those rows is still read
        // (sysInfo, uevent), so they are easy to bring back via `cond` below.
        const full = s.state === UPowerDeviceState.FullyCharged || cap >= 100;
        if (charging)
            add(now, "Time to full", formatTime(s.timeToFull) || "–");
        else if (discharging)
            add(now, "Time to empty", formatTime(s.timeToEmpty) || "–");
        else
            add(now, "Time to full", full ? "Full" : "–");
        const rate = Math.abs(s.changeRate || 0);
        add(now, charging ? "Charge rate" : "Power draw",
            (charging || discharging) && rate >= 0.01 ? rate.toFixed(2).padStart(5) + " W" : "–");

        const level = cap <= 20 ? "critical" : (cap <= 30 ? "warning" : "normal");
        return {
            text: text,
            rows: now.concat(now.length > 0 && cond.length > 0 ? [null] : [], cond),
            level: level,
            pulse: level === "critical" && discharging
        };
    }

    // Test hook: a batteryView() input object ({ pct, state, onBattery, ... }) shown instead of
    // the real battery, e.g. { pct: 0.15, state: UPowerDeviceState.Discharging, onBattery: true }.
    property var batteryOverride: null
    readonly property bool pulsing: pulseAnim.running

    readonly property var _batSys: ({
        designWh: sysInfo.designWh, health: health, cycles: sysInfo.cycles, limit: chargeLimit, kind: sysInfo.kind
    })
    readonly property var batView: batteryOverride ? batteryView(Object.assign({
        timeToEmpty: 0, timeToFull: 0, changeRate: 0, energy: 0, energyFull: 0
    }, _batSys, batteryOverride)) : batOk ? batteryView(Object.assign({
        pct: bat.percentage,
        state: bat.state,
        onBattery: UPower.onBattery,
        timeToEmpty: bat.timeToEmpty,
        timeToFull: bat.timeToFull,
        changeRate: bat.changeRate,
        energy: bat.energy,
        energyFull: bat.energyCapacity
    }, _batSys)) : ({ text: "", rows: [], level: "normal", pulse: false })

    function levelColor(level) {
        // Lightened to a readable contrast (user 2026-11-11: color2 was too dark on the pill).
        const c = level === "critical" ? Theme.color1 : (level === "warning" ? Theme.color3 : Theme.color2);
        return Theme.readable(c, 4.5);
    }

    function reloadSysfs() {
        if (sysfsDir === "")
            return;
        ueventFile.reload();
        startFile.reload();
        endFile.reload();
    }

    FileView {
        id: ueventFile
        path: root.sysfsDir !== "" ? root.sysfsDir + "uevent" : ""
        printErrors: false
        onLoaded: root.uevent = root.parseUevent(text())
    }
    FileView {
        id: startFile
        path: root.sysfsDir !== "" ? root.sysfsDir + "charge_control_start_threshold" : ""
        printErrors: false
        onLoaded: root.startThreshold = parseInt(text()) >= 0 ? parseInt(text()) : -1
    }
    FileView {
        id: endFile
        path: root.sysfsDir !== "" ? root.sysfsDir + "charge_control_end_threshold" : ""
        printErrors: false
        onLoaded: root.endThreshold = parseInt(text()) >= 0 ? parseInt(text()) : -1
    }

    // ======================================================================================
    // segments
    // ======================================================================================
    Segment {
        id: tempSeg
        tooltipComponent: Component {
            InfoTable {
                hints: ["Open CPU Usage: " + root.leftClick]
                rows: root.cpuRows(root.cpuUsage, root.cpuMhz, root.topCpu)
            }
        }
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                Run.floating("btop -p 1");
        }

        BarText {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            color: root.tempCritical ? Theme.color1 : Theme.color5
            text: root.thermoIcon + " " + root.temp + "°C"
            Behavior on color {
                ColorAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
            }
        }
    }

    Segment {
        id: memSeg
        tooltipComponent: Component {
            InfoTable {
                hints: ["Open Memory Usage: " + root.leftClick]
                rows: root.memRows(root.mem, root.topMem)
            }
        }
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                Run.floating("btop -p 3");
        }

        BarText {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.memIcon + " " + root.memPercent(root.mem) + "%" // default colour, as in Waybar
        }
    }

    Segment {
        id: batSeg
        visible: root.batOk || root.batteryOverride !== null
        acceptedButtons: Qt.LeftButton
        tooltipComponent: Component {
            InfoTable {
                hints: ["Change Power Settings: " + root.leftClick]
                rows: root.batView.rows
            }
        }
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                // TODO(power settings): open the power settings here. Intentionally does nothing yet.
            }
        }
        onHoveredChanged: if (hovered) root.reloadSysfs()

        BarText {
            id: batText
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            color: root.levelColor(root.batView.level)
            text: root.batView.text
            Behavior on color {
                ColorAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
            }
        }

        // Critical and discharging: slow pulse, the bar's only constant animation (user decision).
        SequentialAnimation {
            id: pulseAnim
            running: root.batView.pulse
            loops: Animation.Infinite
            NumberAnimation { target: batText; property: "opacity"; to: 0.45; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { target: batText; property: "opacity"; to: 1; duration: 800; easing.type: Easing.InOutSine }
            onRunningChanged: running ? pulseRestore.stop() : pulseRestore.start()
        }
        NumberAnimation {
            id: pulseRestore
            target: batText
            property: "opacity"
            to: 1
            duration: Theme.animNormal
            easing.type: Easing.OutCubic
        }
    }
}
