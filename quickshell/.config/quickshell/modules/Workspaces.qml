import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.components

// Hyprland workspaces of this bar's monitor (Waybar hyprland/workspaces, all-outputs: false,
// disable-scroll: true, on-click: activate). Colours follow pywal (CLAUDE.md user decision).
// A single rounded pill slides behind the focused workspace.
// Hover tooltip (user request 2026-11-11): the apps open on that workspace, one line per app
// with its icon, grouped with a count ("kitty ×3"), most windows first. Empty workspace: none.
//
//   Workspaces { barScreen: bar.screen }
PillGroup {
    id: root

    property var barScreen: null

    readonly property int buttonPadding: 5    // #workspaces button { padding: 5px } (user tried 8, kept 5)
    readonly property int buttonMargin: 5     // #workspaces button { margin-right: 5px }
    readonly property int highlightMargin: 4  // focus pill + urgent bg: top/bottom inset

    // Readable app name for a Hyprland toplevel: { name, appId, unknown }.
    // User choice 2026-11-11: the desktop entry's display name ("Firefox", "WebCord", "btop++").
    // Fallbacks: the appId (Wayland first, then Hyprland's class; reverse-DNS ids keep the last
    // part, md.obsidian.Obsidian -> Obsidian). Popups launched as `kitty --class floating <cmd>`
    // use <cmd>; windows without a class use their title (truncated).
    function desktopName(id: string): string {
        DesktopEntries.applications.values;   // re-evaluate once the entries are scanned
        return id ? (DesktopEntries.heuristicLookup(id)?.name ?? "") : "";
    }

    function appInfo(t: HyprlandToplevel): var {
        const id = t.wayland?.appId || t.lastIpcObject?.class || "";
        const title = (t.title || t.wayland?.title || "").trim();
        if (id === "floating") {
            const cmd = title.split(/\s+/)[0] || id;
            return { name: desktopName(cmd) || cmd, appId: cmd, unknown: false };
        }
        if (id === "") {
            const chars = [...title];
            const name = chars.length > 20 ? chars.slice(0, 19).join("") + "…" : (title || "?");
            return { name: name, appId: "", unknown: true };
        }
        const parts = id.split(".");
        return { name: desktopName(id) || (parts.length >= 3 ? parts[parts.length - 1] : id), appId: id, unknown: false };
    }

    // Icon for an app (desktop entry icon, else the id itself as an icon name), "" if none.
    function appIcon(appId: string, name: string): string {
        DesktopEntries.applications.values;   // re-evaluate once the entries are scanned
        const entry = appId ? DesktopEntries.heuristicLookup(appId) : null;
        return (entry?.icon ? Quickshell.iconPath(entry.icon, true) : "")
            || (appId ? Quickshell.iconPath(appId, true) : "")
            || Quickshell.iconPath(name.toLowerCase(), true);
    }

    Segment {
        id: seg

        // #workspaces { padding-left: 5px; padding-right: 0 }. The last button's
        // margin-right (5px) is added here, the others come from the row spacing.
        leftPadding: 5
        rightPadding: root.buttonMargin
        spacing: root.buttonMargin

        // The pill always follows the last focused button on this monitor. It never goes back
        // to "no target" when a focus change arrives as unfocus-old before focus-new, or when the
        // old (empty) workspace is destroyed. Doing that used to turn the slide animation off.
        property Item pillTarget: null
        // Where the pill stays while pillTarget is briefly null (its button was destroyed).
        property real frozenX: 0
        property real frozenWidth: 0
        // The focused workspace is one of the shown buttons (every bar shows all workspaces since
        // 2026-11-11, so this is false only for special workspaces; then the pill fades out).
        readonly property bool focusHere: {
            const ws = Hyprland.focusedWorkspace;
            return !!ws && ws.id > 0 && !ws.name.startsWith("special:");
        }
        // False until the pill has been shown in place once, so it never slides in from x = 0.
        property bool pillPlaced: false

        onPillTargetChanged: if (pillTarget && !pillPlaced) placeTimer.restart()
        onFocusHereChanged: if (!focusHere) { pillPlaced = false; placeTimer.stop(); }

        // One-shot: lets the Row lay out the button before x/width start animating.
        Timer {
            id: placeTimer
            interval: Theme.animNormal
            onTriggered: seg.pillPlaced = seg.focusHere
        }

        underlay: Rectangle {
            id: focusPill

            readonly property Item target: seg.pillTarget

            x: target ? seg.leftPadding + target.x : seg.frozenX
            width: target ? target.width : seg.frozenWidth
            y: root.highlightMargin
            height: seg.height - 2 * root.highlightMargin
            radius: Theme.pillRadius
            color: Theme.wsPill
            opacity: seg.focusHere && (target || seg.frozenWidth > 0) ? 1 : 0
            visible: opacity > 0

            Behavior on x {
                enabled: seg.pillPlaced
                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
            }
            Behavior on width {
                enabled: seg.pillPlaced
                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: Theme.animFast }
            }
        }

        Repeater {
            model: ScriptModel {
                values: Hyprland.workspaces.values
                    // All normal workspaces, on every monitor (user request 2026-11-11; Waybar had
                    // all-outputs: false). barScreen is kept in the API but no longer filters.
                    .filter(w => w.id > 0 && !w.name.startsWith("special:"))
                    .sort((a, b) => a.id - b.id)
            }

            delegate: Item {
                id: button

                required property HyprlandWorkspace modelData
                readonly property bool isFocused: modelData.focused
                readonly property bool isUrgent: modelData.urgent

                // [{ name, appId, count, unknown }], most windows first, then by name. Live: it
                // follows toplevels opening/closing/moving while the tooltip is shown.
                readonly property var apps: {
                    const groups = {};
                    for (const t of modelData.toplevels.values) {
                        const info = root.appInfo(t);
                        if (!groups[info.name])
                            groups[info.name] = { name: info.name, appId: info.appId, count: 0, unknown: info.unknown };
                        groups[info.name].count++;
                    }
                    return Object.values(groups).sort((a, b) =>
                        b.count - a.count || a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
                }

                implicitWidth: label.implicitWidth + 2 * root.buttonPadding
                width: implicitWidth
                height: seg.height

                onIsFocusedChanged: if (isFocused) seg.pillTarget = button
                Component.onCompleted: if (isFocused) seg.pillTarget = button
                Component.onDestruction: {
                    if (seg.pillTarget === button) {
                        seg.frozenX = focusPill.x;
                        seg.frozenWidth = focusPill.width;
                        seg.pillTarget = null;
                    }
                }

                // #workspaces button.urgent
                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: root.highlightMargin
                    anchors.bottomMargin: root.highlightMargin
                    radius: Theme.pillRadius
                    color: Theme.wsUrgentBg
                    opacity: button.isUrgent ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
                    }
                }

                BarText {
                    id: label
                    anchors.centerIn: parent
                    text: button.modelData.name
                    // CSS order in Waybar: :hover overrides .urgent overrides .active.
                    color: mouse.containsMouse ? Theme.foreground
                         : button.isUrgent ? Theme.wsUrgentFg
                         : (button.modelData.active || button.isFocused) ? Theme.wsActive
                         : Theme.wsInactive

                    Behavior on color {
                        ColorAnimation { duration: Theme.animFast }
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    onClicked: button.modelData.activate()
                    // A window with neither a Wayland appId nor an IPC class yet: ask Hyprland
                    // once (on hover only, never polled).
                    onContainsMouseChanged: {
                        if (containsMouse && button.apps.some(a => a.unknown))
                            Hyprland.refreshToplevels();
                    }
                }

                Tooltip {
                    target: button
                    component: button.apps.length > 0 ? appsTip : null
                    show: mouse.containsMouse
                }

                Component {
                    id: appsTip

                    Column {
                        spacing: 2

                        Repeater {
                            model: button.apps

                            Row {
                                id: appRow

                                required property var modelData
                                readonly property string icon: root.appIcon(modelData.appId, modelData.name)

                                spacing: 8

                                Item {
                                    implicitWidth: 16
                                    implicitHeight: 16
                                    anchors.verticalCenter: parent.verticalCenter

                                    IconImage {
                                        anchors.fill: parent
                                        source: appRow.icon
                                        asynchronous: true
                                        visible: appRow.icon !== ""
                                    }
                                    BarText {
                                        anchors.centerIn: parent
                                        visible: appRow.icon === ""
                                        text: String.fromCodePoint(0xf08c6)   // nf-md-application
                                        font.pixelSize: 16
                                    }
                                }

                                BarText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    textFormat: Text.PlainText
                                    text: appRow.modelData.name
                                }

                                BarText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: appRow.modelData.count > 1
                                    color: Theme.wsInactive
                                    text: "\u00d7" + appRow.modelData.count
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
