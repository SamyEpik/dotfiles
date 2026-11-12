import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.components

// One tray menu entry (a QsMenuEntry): separator, or a row with an optional check/radio
// glyph, icon, label and submenu chevron.
//
// Submenus expand inline under their entry (accordion), indented one step. That keeps the
// whole menu on one surface with one input mask and one focus grab, and needs no placement
// logic for nested panels at the screen edge. The nested list loads through a Loader by URL
// (QML can't instantiate a component inside itself) and unrefs its menu when collapsed.
ColumnLayout {
    id: entry

    required property var modelData // QsMenuEntry
    property int depth: 0
    property bool expanded: false

    // This entry (or one in its submenu) was triggered: close the menu.
    signal done

    readonly property bool isSep: modelData?.isSeparator ?? false
    readonly property bool isEnabled: modelData?.enabled ?? false
    readonly property bool hasSub: modelData?.hasChildren ?? false
    readonly property int buttonType: modelData?.buttonType ?? QsMenuButtonType.None
    readonly property bool checked: (modelData?.checkState ?? Qt.Unchecked) !== Qt.Unchecked
    readonly property string iconSource: modelData?.icon ?? ""

    // Nerd Font (Material Design) glyphs.
    readonly property string checkGlyph: buttonType === QsMenuButtonType.RadioButton
        ? String.fromCodePoint(checked ? 0xf043e : 0xf043d)  // 󰐾 radiobox_marked / 󰐽 radiobox_blank
        : String.fromCodePoint(checked ? 0xf0132 : 0xf0131)  // 󰄲 checkbox_marked / 󰄱 checkbox_blank_outline
    readonly property string chevronGlyph: String.fromCodePoint(0xf0142) // 󰅂 chevron_right

    readonly property int rowPadding: 10
    readonly property int indent: 14

    spacing: 0

    // ---- separator ----------------------------------------------------------------------
    Item {
        visible: entry.isSep
        Layout.fillWidth: true
        implicitHeight: 9

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 2 * entry.rowPadding
            height: 1
            color: Theme.color8
        }
    }

    // ---- row ----------------------------------------------------------------------------
    Item {
        id: row

        visible: !entry.isSep
        Layout.fillWidth: true
        implicitHeight: 30
        implicitWidth: entry.rowPadding + entry.depth * entry.indent + content.implicitWidth
                       + (entry.hasSub ? content.spacing + chevron.implicitWidth : 0) + entry.rowPadding
        opacity: entry.isEnabled ? 1 : 0.4

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: Theme.wsPill
            opacity: hover.hovered && entry.isEnabled ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        }

        Row {
            id: content
            x: entry.rowPadding + entry.depth * entry.indent
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            BarText {
                visible: entry.buttonType !== QsMenuButtonType.None
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: entry.checkGlyph
            }

            IconImage {
                visible: entry.iconSource !== ""
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 16
                asynchronous: true
                source: entry.iconSource
            }

            BarText {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: entry.modelData?.text ?? ""
            }
        }

        BarText {
            id: chevron
            visible: entry.hasSub
            anchors.right: parent.right
            anchors.rightMargin: entry.rowPadding
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: entry.chevronGlyph
            rotation: entry.expanded ? 90 : 0
            Behavior on rotation { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        }

        HoverHandler {
            id: hover
            enabled: entry.isEnabled
        }

        MouseArea {
            anchors.fill: parent
            enabled: entry.isEnabled
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {
                if (entry.hasSub) {
                    entry.expanded = !entry.expanded;
                } else {
                    entry.modelData.triggered();
                    entry.done();
                }
            }
        }
    }

    // ---- inline submenu ------------------------------------------------------------------
    Item {
        id: subWrap

        visible: entry.hasSub && implicitHeight > 0
        Layout.fillWidth: true
        clip: true
        implicitWidth: sub.item ? sub.item.implicitWidth : 0
        implicitHeight: entry.expanded && sub.item ? sub.item.implicitHeight : 0
        Behavior on implicitHeight { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

        Loader {
            id: sub
            width: parent.width
            // Stays loaded until the collapse animation has finished.
            active: entry.hasSub && (entry.expanded || subWrap.implicitHeight > 0)
            source: "TrayMenuList.qml"
            onLoaded: {
                item.depth = entry.depth + 1;
                item.handle = Qt.binding(() => entry.modelData);
            }
        }

        Connections {
            target: sub.item
            ignoreUnknownSignals: true
            function onDone() {
                entry.done();
            }
        }
    }
}
