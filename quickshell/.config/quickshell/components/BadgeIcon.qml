import QtQuick
import QtQuick.Effects
import qs

// A full-size glyph with a small badge glyph at its bottom-right corner (user choice "B1",
// 2026-11-11: headphones + bluetooth badge, because md-headphones_bluetooth is drawn too small).
//
// Behind the badge, a ring is *knocked out* of the main glyph (MultiEffect mask), so the real
// pill background shows through. A solid disc looked dark: the pill background is translucent
// (Theme.pillOpacity), so no solid colour matches it. The effect is a static layer that is only
// redrawn when the glyph or colour changes.
Item {
    id: b

    property string main: ""
    property string badge: ""
    property color color: Theme.foreground
    property real badgeSize: 10      // badge glyph pixel size
    property real gap: 1.5           // transparent ring around the badge

    implicitWidth: mainText.implicitWidth + 5
    implicitHeight: mainText.implicitHeight

    // Badge box, in this item's coordinates.
    readonly property real badgeBox: 12
    readonly property real badgeX: width - 11
    readonly property real badgeY: height / 2 - 1

    Item {
        id: content
        anchors.fill: parent
        visible: false
        layer.enabled: true

        BarText {
            id: mainText
            anchors.verticalCenter: parent.verticalCenter
            text: b.main
            color: b.color
        }
    }

    Item {
        id: hole
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            x: b.badgeX - b.gap
            y: b.badgeY - b.gap
            width: b.badgeBox + 2 * b.gap
            height: width
            radius: width / 2
            color: "white"
            antialiasing: true
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: content
        maskEnabled: true
        maskSource: hole
        maskInverted: true
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    BarText {
        x: b.badgeX + (b.badgeBox - implicitWidth) / 2
        y: b.badgeY + (b.badgeBox - implicitHeight) / 2
        text: b.badge
        color: b.color
        font.pixelSize: b.badgeSize
    }
}
