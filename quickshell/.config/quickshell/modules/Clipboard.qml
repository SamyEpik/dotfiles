import QtQuick
import Quickshell
import qs
import qs.components

// Clipboard history launcher (Waybar custom/clipboard).
PillGroup {
    id: root

    readonly property string command: "pkill wofi || cliphist list | wofi --dmenu --allow-images | cliphist decode | wl-copy"

    Segment {
        rightPadding: 12
        tooltip: "Open Clipboard"
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                Run.sh(root.command);
        }

        BarText {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.foreground
            text: String.fromCodePoint(0xf1268)
        }
    }
}
