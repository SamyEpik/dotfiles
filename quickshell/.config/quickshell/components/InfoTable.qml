import QtQuick
import QtQuick.Layouts
import qs

// Standard tooltip content (use as `Segment.tooltipComponent: Component { InfoTable { ... } }`):
// click hints on top, a small gap, then label/value rows with the values right-aligned in one
// column. Bindings stay live, so values can update while the tooltip is open; keep values
// fixed-width (e.g. padStart) when they change often, so the box doesn't resize on every tick.
// The table is always at least `overhang` px wider than the widest hint line (the label/value gap
// grows), so a hint's click icon is never the widest thing (user request 2026-11-11).
//
//   InfoTable {
//       hints: ["Open CPU Usage: 󰍽"]
//       rows: [["Usage", root.usage + "%"], null, ["Top", root.topName]]   // null = small gap
//   }
Column {
    id: root

    property var hints: []   // strings, shown first
    property var rows: []    // [label, value] or [label, value, color]; null/[] = gap
    property color labelColor: Theme.foreground
    property color valueColor: Theme.foreground
    property int overhang: 16

    readonly property var _cells: {
        const out = [];
        for (const r of rows) {
            if (!r || r.length === 0) {
                out.push({ gap: true, text: "" });
            } else {
                out.push({ text: String(r[0]) });
                out.push({ text: String(r[1]), right: true, color: r[2] });
            }
        }
        return out;
    }

    spacing: 0

    Column {
        id: hintColumn

        Repeater {
            model: root.hints

            BarText {
                required property var modelData
                text: modelData
                textFormat: Text.PlainText
            }
        }
    }

    Item {
        width: 1
        height: root.hints.length > 0 && root.rows.length > 0 ? 8 : 0
    }

    GridLayout {
        width: Math.max(implicitWidth, root.hints.length > 0 ? hintColumn.implicitWidth + root.overhang : 0)
        columns: 2
        columnSpacing: 24
        rowSpacing: 0
        visible: root.rows.length > 0

        Repeater {
            model: root._cells

            BarText {
                required property var modelData
                text: modelData.text
                textFormat: Text.PlainText
                color: modelData.color ?? (modelData.right ? root.valueColor : root.labelColor)
                Layout.columnSpan: modelData.gap ? 2 : 1
                Layout.alignment: modelData.right ? Qt.AlignRight : Qt.AlignLeft
                // The label column takes any extra width, so values stay flush right.
                Layout.fillWidth: !modelData.right && !modelData.gap
                Layout.preferredHeight: modelData.gap ? 6 : implicitHeight
            }
        }
    }
}
