import QtQuick
import qs

// One joined pill: a single rounded background + border, with Segments laid out inside.
// Outer corners are rounded (10px); joins between segments are square and share one 2px
// border line (Waybar: border-left/right: 0 on the inner side), drawn as row spacing.
//
//   PillGroup {
//       Segment { BarText { text: "" } }
//       Segment { BarText { text: "19:06" } }
//   }
Item {
    id: group

    default property alias segments: row.data

    implicitWidth: row.implicitWidth + 2 * Theme.pillBorder
    implicitHeight: Theme.pillHeight

    Rectangle {
        anchors.fill: parent
        radius: Theme.pillRadius
        color: Theme.background
        border.width: Theme.pillBorder
        border.color: Theme.color0
        opacity: Theme.pillOpacity
    }

    Row {
        id: row
        x: Theme.pillBorder
        y: Theme.pillBorder
        height: parent.height - 2 * Theme.pillBorder
        spacing: Theme.pillBorder
    }
}
