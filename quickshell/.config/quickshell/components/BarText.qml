import QtQuick
import qs

// Text with the bar font (JetBrainsMono Nerd Font, bold, 16px). Use for every label and icon.
Text {
    color: Theme.foreground
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: true
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
