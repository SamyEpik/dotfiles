pragma Singleton

import QtQuick
import Quickshell

// Which pill currently wants the (shared) tooltip. Segments ask through components/Tooltip.qml;
// one components/TooltipHost.qml per bar draws it (user decision 2026-11-11: one tooltip that
// glides between pills).
//
// release() does not close at once: the tooltip "hangs" for hangMs, so moving to the next pill
// keeps it open and it glides there instead of closing and reopening.
Singleton {
    id: root

    property Item target: null
    property string text: ""
    property Component component: null   // rich content instead of text (e.g. the calendar)
    property bool active: false   // a tooltip is shown (or hanging)
    property int revision: 0      // bumped after every change; hosts sync on it

    readonly property int hangMs: 200

    function request(t: Item, txt: string, comp: Component): void {
        hang.stop();
        target = t;
        text = txt;
        component = comp ?? null;
        active = true;
        revision++;
    }

    // Text of the shown tooltip changed (e.g. volume while scrolling).
    function update(t: Item, txt: string, comp: Component): void {
        if (active && target === t && (text !== txt || component !== (comp ?? null))) {
            text = txt;
            component = comp ?? null;
            revision++;
        }
    }

    function release(t: Item): void {
        if (active && target === t)
            hang.restart();
    }

    // Target is being destroyed: close at once.
    function drop(t: Item): void {
        if (target === t) {
            hang.stop();
            active = false;
            revision++;
        }
    }

    Timer {
        id: hang
        interval: root.hangMs
        onTriggered: {
            root.active = false;
            root.revision++;
        }
    }
}
