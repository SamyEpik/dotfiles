import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.components

// Custom pywal tray menu (user decision 2026-11-11: not the native Qt menu). One per bar,
// owned by modules/Tray.qml:
//
//   TrayMenu { id: menu; bar: root.QsWindow.window }
//   menu.open(trayItem, iconItem, pillItem)   // shows trayItem.menu under iconItem
//   menu.close()
//
// Look and motion follow components/TooltipHost.qml: a box (background 0.9, radius 10, 2px
// color5 border) on an overlay layer surface right under the bar. It starts at the pill's width
// behind the pill's bottom edge, then slides down `gap` px while growing to its own width and
// fading in (220 ms OutCubic). Closing reverses it (150 ms InCubic); the surface stays mapped
// until then. The box is centred under the clicked icon and kept `gap` px from the screen edges.
//
// DBusMenu loads the entries asynchronously after the menu is referenced, so the box waits
// (up to `loadWaitMs`) for the first entries before it slides out, instead of growing visibly.
//
// Closing: an entry is triggered, Escape (keyboard focus OnDemand, given by the focus grab), an
// outside click (HyprlandFocusGrab; if Hyprland rejects the grab, the surface's mask grows to
// the whole surface and a click on it closes the menu), or close() from the owner (item gone).
Item {
    id: menu

    required property var bar          // the bar PanelWindow (for the screen)
    property int gap: 8
    property int padding: 4            // between border and entries
    property int minWidth: 160
    property int loadWaitMs: 300

    property bool isOpen: false        // logically open (the owner's icon shows it as open)
    property bool revealed: false      // the box is out (drives the motion)
    property bool mapped: false
    property var owner: null           // the SystemTrayItem whose menu is shown
    property var handle: null          // its QsMenuHandle (null = unref'd)

    // Geometry captured at open(), in bar/surface x coordinates.
    property real anchorX: 0
    property real pillX: 0
    property real pillWidth: 0

    // Outside click via the focus grab: lets the owner ignore the same click on its own icon.
    property var grabClosedOwner: null
    property double grabClosedAt: 0
    property double grabActivatedAt: 0
    property bool grabFailed: false

    readonly property int inset: Theme.pillBorder + padding
    readonly property real boxWidth: Math.max(minWidth, list.implicitWidth + 2 * inset)
    readonly property real listHeight: list.count > 0 ? list.implicitHeight : 30 // 30: "No entries" row
    readonly property real boxHeight: Math.min(listHeight + 2 * inset, win.height - 2 * gap)
    readonly property real finalX: Math.max(gap, Math.min(win.width - gap - boxWidth, anchorX - boxWidth / 2))

    visible: false

    function open(item: var, anchorItem: Item, pillItem: Item): void {
        if (!item || !item.hasMenu || !item.menu)
            return;
        const a = anchorItem.mapToItem(null, anchorItem.width / 2, 0);
        const p = pillItem.mapToItem(null, 0, 0);
        const r = Theme.pillRadius;
        const w = Math.max(2 * r, pillItem.width - 2 * r);
        anchorX = a.x;
        pillX = p.x + (pillItem.width - w) / 2;
        pillWidth = w;

        unmapTimer.stop();
        if (owner !== item) {
            revealed = false;
            owner = item;
        }
        handle = item.menu;
        isOpen = true;
        mapped = true;
        if (list.count > 0)
            revealed = true;
        else
            loadTimer.restart();
        Qt.callLater(activateGrab);
    }

    function close(): void {
        if (!isOpen)
            return;
        isOpen = false;
        revealed = false;
        loadTimer.stop();
        grab.active = false;
        unmapTimer.restart();
    }

    // True if the menu of `item` was just closed by the outside click that is now arriving as
    // a click on its own icon: that click should not reopen it.
    function justClosedBy(item: var): bool {
        return grabClosedOwner === item && Date.now() - grabClosedAt < 400;
    }

    function activateGrab(): void {
        if (isOpen && !grabFailed) {
            grabActivatedAt = Date.now();
            grab.active = true;
        }
    }

    // The menu went away (the owner calls close() when its item goes).
    onHandleChanged: if (isOpen && !handle) close()

    Connections {
        target: list
        function onCountChanged() {
            if (menu.isOpen && !menu.revealed && list.count > 0) {
                loadTimer.stop();
                menu.revealed = true;
            }
        }
    }

    // Menu still empty after loadWaitMs: show it anyway (with the "empty" row).
    Timer {
        id: loadTimer
        interval: menu.loadWaitMs
        onTriggered: if (menu.isOpen) menu.revealed = true
    }

    // Unmap and unref after the close animation.
    Timer {
        id: unmapTimer
        interval: 170
        onTriggered: {
            if (!menu.isOpen) {
                menu.mapped = false;
                menu.handle = null;
                menu.owner = null;
            }
        }
    }

    HyprlandFocusGrab {
        id: grab
        windows: [win]
        onCleared: {
            if (Date.now() - menu.grabActivatedAt < 150) {
                // Rejected right away (not a click): fall back to the full-surface mask.
                menu.grabFailed = true;
                console.warn("TrayMenu: HyprlandFocusGrab was cleared at once, using the click-catcher fallback");
                return;
            }
            if (menu.isOpen) {
                menu.grabClosedOwner = menu.owner;
                menu.grabClosedAt = Date.now();
                menu.close();
            }
        }
    }

    PanelWindow {
        id: win

        screen: menu.bar ? menu.bar.screen : null
        anchors {
            top: true
            left: true
            right: true
        }
        margins.top: Theme.barHeight
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-traymenu"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        // Fixed size (never animated): the rest of the screen below the bar.
        implicitHeight: (screen ? screen.height : 1200) - Theme.barHeight
        color: "transparent"
        visible: menu.mapped
        // Only the box takes input; with the fallback the whole surface does (to catch clicks).
        mask: Region {
            item: menu.grabFailed ? clipArea : box
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: menu.close()
        }

        // Clips at the bar's bottom edge, so the box seems to come out from behind the pill.
        Item {
            id: clipArea
            anchors.fill: parent
            clip: true

            // Fallback outside-click catcher (only when the focus grab doesn't work).
            MouseArea {
                anchors.fill: parent
                enabled: menu.grabFailed && menu.isOpen
                acceptedButtons: Qt.AllButtons
                onPressed: menu.close()
            }

            Item {
                id: box

                // Motion: out = under the icon; in = pill-sized behind the pill's bottom edge.
                property int duration: menu.revealed ? 220 : 150
                property int easing: menu.revealed ? Easing.OutCubic : Easing.InCubic

                x: menu.revealed ? menu.finalX : menu.pillX
                y: menu.revealed ? menu.gap : -height
                width: menu.revealed ? menu.boxWidth : menu.pillWidth
                height: menu.boxHeight
                opacity: menu.revealed ? 1 : 0
                clip: true

                Behavior on x { NumberAnimation { duration: box.duration; easing.type: box.easing } }
                Behavior on y { NumberAnimation { duration: box.duration; easing.type: box.easing } }
                Behavior on width { NumberAnimation { duration: box.duration; easing.type: box.easing } }
                Behavior on opacity { NumberAnimation { duration: box.duration; easing.type: box.easing } }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.pillRadius
                    color: Theme.background
                    border.width: Theme.pillBorder
                    border.color: Theme.color5
                    opacity: 0.9
                }

                // The entries stay at their final place while the box grows around them.
                Flickable {
                    x: menu.finalX - box.x + menu.inset
                    y: menu.inset
                    width: menu.boxWidth - 2 * menu.inset
                    height: menu.boxHeight - 2 * menu.inset
                    contentWidth: width
                    contentHeight: list.implicitHeight
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    TrayMenuList {
                        id: list
                        width: parent.width
                        handle: menu.handle
                        onDone: menu.close()
                    }
                }

                BarText {
                    visible: menu.revealed && list.count === 0
                    anchors.centerIn: parent
                    opacity: 0.4
                    textFormat: Text.PlainText
                    text: "No entries"
                }
            }
        }
    }
}
