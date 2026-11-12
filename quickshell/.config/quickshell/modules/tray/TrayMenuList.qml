import QtQuick
import QtQuick.Layouts
import Quickshell

// One level of a tray menu: lists the entries of `handle` (a QsMenuHandle: the tray item's
// `menu`, or a QsMenuEntry with children). Submenus nest another TrayMenuList inside the
// entry (inline expansion, see TrayMenuEntry.qml).
//
// The QsMenuOpener refs the menu while `handle` is set (DBusMenu loads the layout then);
// set `handle: null` to release it.
ColumnLayout {
    id: list

    property var handle: null
    property int depth: 0
    readonly property int count: rep.count

    // An entry was triggered: the whole menu should close.
    signal done

    spacing: 0

    QsMenuOpener {
        id: opener
        menu: list.handle
    }

    Repeater {
        id: rep
        model: opener.children

        delegate: TrayMenuEntry {
            Layout.fillWidth: true
            depth: list.depth
            onDone: list.done()
        }
    }
}
