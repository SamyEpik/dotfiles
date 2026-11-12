import QtQuick
import qs

// Label that
//  - truncates to `maxChars` code points with "…" (Waybar max-length; 0 = no limit),
//  - and/or elides with "…" at `maxWidth` pixels (for space-limited pills, like GTK did),
//  - cross-fades old -> new text when `text` changes,
//  - scrolls the full text (marquee, ping-pong) while `hovered` and truncated or elided. The marquee
//    animation only runs while hovered, so nothing animates when idle.
// Its implicitWidth follows the new text right away; the parent Segment animates the width.
Item {
    id: root

    property string text: ""
    property int maxChars: 0
    property real maxWidth: 1e9
    property bool hovered: false
    property color color: Theme.foreground
    property real marqueeSpeed: 40 // px per second

    // Spread, not Array.from: Qt's JS engine splits non-BMP chars (emoji) with Array.from.
    readonly property bool truncated: maxChars > 0 && [...text].length > maxChars
    readonly property string shownText: truncated ? [...text].slice(0, maxChars - 1).join("") + "…" : text
    readonly property real _naturalWidth: _useA ? a.implicitWidth : b.implicitWidth
    readonly property bool elided: _naturalWidth > maxWidth
    readonly property bool _marquee: hovered && (truncated || elided)

    property bool _useA: true

    implicitWidth: Math.min(_naturalWidth, maxWidth)
    implicitHeight: a.implicitHeight
    clip: true

    onShownTextChanged: {
        if (_useA)
            b.text = shownText;
        else
            a.text = shownText;
        _useA = !_useA;
    }
    Component.onCompleted: a.text = shownText

    BarText {
        id: a
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, root.maxWidth)
        elide: Text.ElideRight
        color: root.color
        textFormat: Text.PlainText
        // Marquee on/off swaps instantly (visible), text changes cross-fade (opacity). Fading the
        // marquee in/out made both layers half-transparent for a moment (a grey flash).
        visible: !root._marquee
        opacity: root._useA ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
    }

    BarText {
        id: b
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, root.maxWidth)
        elide: Text.ElideRight
        color: root.color
        textFormat: Text.PlainText
        visible: !root._marquee
        opacity: root._useA ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
    }

    BarText {
        id: full
        anchors.verticalCenter: parent.verticalCenter
        color: root.color
        textFormat: Text.PlainText
        text: root.text
        visible: root._marquee

        readonly property real travel: Math.max(0, implicitWidth - root.width)
        readonly property int travelMs: Math.max(1, travel / root.marqueeSpeed * 1000)

        SequentialAnimation on x {
            running: root._marquee
            loops: Animation.Infinite
            PauseAnimation { duration: 700 }
            NumberAnimation { from: 0; to: -full.travel; duration: full.travelMs; easing.type: Easing.InOutSine }
            PauseAnimation { duration: 700 }
            NumberAnimation { from: -full.travel; to: 0; duration: full.travelMs; easing.type: Easing.InOutSine }
        }
    }

    on_MarqueeChanged: if (!_marquee) full.x = 0
}
