import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs
import qs.components
import qs.modules.tray

// [tray]: replaces Waybar's `tray` (icon-size 18, spacing 10, show-passive-items: true).
// Its own pill. Every StatusNotifierItem is shown, passive ones too. Items appearing or
// disappearing change the content width, which Segment animates.
//
//   left click    activate()   (items with onlyMenu open their menu instead)
//   middle click  secondaryActivate()
//   right click   custom pywal menu (modules/tray/TrayMenu.qml), click again to close
//   scroll        scroll(delta, horizontal)
//
// Each icon has its own tooltip through the shared tooltip host; it is hidden while that
// icon's menu is open.
PillGroup {
    id: root

    visible: SystemTray.items.values.length > 0

    function openMenu(item: var, icon: Item): void {
        if (menu.isOpen && menu.owner === item) {
            menu.close();
            return;
        }
        if (menu.justClosedBy(item))
            return; // this click closed it through the focus grab
        TooltipState.drop(icon);
        menu.open(item, icon, root);
    }

    Segment {
        id: seg

        spacing: 10

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: icon

                required property SystemTrayItem modelData

                // Full segment height, so the whole pill height is clickable/hoverable.
                implicitWidth: 18
                height: seg.height

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 18
                    asynchronous: true
                    source: icon.modelData.icon
                }

                HoverHandler {
                    id: hover
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: mouse => {
                        const item = icon.modelData;
                        if (mouse.button === Qt.LeftButton) {
                            if (item.onlyMenu && item.hasMenu)
                                root.openMenu(item, icon);
                            else
                                item.activate();
                        } else if (mouse.button === Qt.MiddleButton) {
                            item.secondaryActivate();
                        } else if (mouse.button === Qt.RightButton) {
                            if (item.hasMenu)
                                root.openMenu(item, icon);
                        }
                    }
                    onWheel: wheel => {
                        if (wheel.angleDelta.y !== 0)
                            icon.modelData.scroll(wheel.angleDelta.y, false);
                        else if (wheel.angleDelta.x !== 0)
                            icon.modelData.scroll(wheel.angleDelta.x, true);
                    }
                }

                Tooltip {
                    target: icon
                    text: icon.modelData.tooltipTitle || icon.modelData.title || icon.modelData.id
                    show: hover.hovered && !(menu.isOpen && menu.owner === icon.modelData)
                }

                Component.onDestruction: {
                    if (menu.owner === icon.modelData)
                        menu.close();
                }
            }
        }
    }

    TrayMenu {
        id: menu
        bar: root.QsWindow.window
    }
}
