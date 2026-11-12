import QtQuick
import qs

// One module inside a PillGroup (Waybar "module"). Handles padding, smooth width changes,
// hover, clicks, scroll and the tooltip, so modules only provide content.
//
//   Segment {
//       tooltip: "Open X: 󰍽"
//       onClicked: mouse => { if (mouse.button === Qt.LeftButton) ... }
//       onScrolled: wheel => ...            // wheel.angleDelta.y > 0 = scroll up
//       BarText { anchors.verticalCenter: parent.verticalCenter; text: "…" }
//   }
//
// Children go into a Row (vertically: use anchors.verticalCenter). Put backgrounds that must
// sit under the content (progress fill, highlight) into `underlay`.
Item {
    id: seg

    default property alias content: contentRow.data
    property alias underlay: underlayItem.data
    property alias spacing: contentRow.spacing

    property int leftPadding: Theme.pillPadding
    property int rightPadding: Theme.pillPadding
    property real contentWidth: contentRow.implicitWidth
    property bool animateWidth: true

    property string tooltip: ""
    // Rich tooltip content instead of text: an Item with implicit size, shown in the shared tooltip
    // box (e.g. the clock's calendar). Overrides `tooltip`.
    property Component tooltipComponent: null
    readonly property bool hovered: hover.hovered

    property int acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    signal clicked(var mouse)
    signal scrolled(var wheel)

    implicitWidth: contentWidth + leftPadding + rightPadding
    // Height comes from the PillGroup row (pillHeight minus the border).
    height: parent ? parent.height : Theme.pillHeight - 2 * Theme.pillBorder
    clip: true

    Behavior on implicitWidth {
        enabled: seg.animateWidth
        NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
    }

    HoverHandler { id: hover }

    // Below the content so child MouseAreas (e.g. workspace buttons) still get their clicks.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: seg.acceptedButtons
        onClicked: mouse => seg.clicked(mouse)
        onWheel: wheel => seg.scrolled(wheel)
    }

    Item {
        id: underlayItem
        anchors.fill: parent
    }

    Row {
        id: contentRow
        x: seg.leftPadding
        height: parent.height
        opacity: Theme.contentOpacity
    }

    Tooltip {
        target: seg
        text: seg.tooltipComponent ? "" : seg.tooltip
        component: seg.tooltipComponent
        show: seg.hovered
    }
}
