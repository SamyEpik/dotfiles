//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.modules

// Entry point: one bar per screen. Layout mirrors Waybar's modules-left/center/right.
// Only the main session edits this file (see CLAUDE.md "Agent workflow").
ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar

            required property ShellScreen modelData

            screen: modelData
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: Theme.barHeight
            exclusiveZone: Theme.barHeight
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell-bar"

            Row {
                id: leftModules
                x: Theme.edgeGap
                y: Theme.pillTop
                spacing: Theme.groupGap

                ArchClock {}
                Workspaces {
                    barScreen: bar.screen
                }
                // Hidden on eDP-1 when it is scaled above 1.0 (user request 2026-11-11). Hyprland's
                // monitor scale isn't populated in Quickshell, but the device pixel ratio is
                // (fractional scales round up: 1.25 -> 2), so "> 1" works.
                Clipboard {
                    visible: !(bar.screen.name === "eDP-1" && bar.screen.devicePixelRatio > 1)
                }
            }

            // Centred like Waybar's modules-center, but never over the side groups: it slides
            // sideways when needed, and the window title gets only the space that is left.
            Row {
                id: centerModules

                readonly property real minX: leftModules.x + leftModules.width + Theme.groupGap
                readonly property real maxRight: rightModules.x - Theme.groupGap

                x: Math.max(minX, Math.min(maxRight - width, (parent.width - width) / 2))
                y: Theme.pillTop
                spacing: Theme.groupGap

                // Space left for the title after the media group. Below 80px the title hides,
                // so a full bar keeps its gaps (user report 2026-11-11: media touched wifi).
                WindowTitle {
                    readonly property real room: centerModules.maxRight - centerModules.minX - media.width - Theme.groupGap
                    maxWidth: room
                    visible: room >= 80
                }
                // Media keeps its size unless it alone doesn't fit; then its title elides.
                Media {
                    id: media
                    maxWidth: centerModules.maxRight - centerModules.minX
                }
            }

            Row {
                id: rightModules
                anchors.right: parent.right
                anchors.rightMargin: Theme.edgeGap
                y: Theme.pillTop
                spacing: Theme.groupGap

                // Waybar order: network|bluetooth, cputemp|memory|battery, volume|mic, tray.
                NetBt {}
                Stats {}
                Audio {}
                Tray {}
            }

            // The bar's one shared tooltip (glides between pills).
            TooltipHost {
                bar: bar
            }
        }
    }
}
