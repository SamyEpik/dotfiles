import QtQuick
import QtQuick.Shapes
import qs

// Line-style wifi icon drawn in QML (user choice "W3", 2026-11-11): a dot plus 3 arcs. `level`
// 0..4 of them are lit in `color`, the rest stay faint. `slashed` adds a diagonal stroke
// (disconnected). `size` is the icon height; everything scales from it. 13px (user request
// 2026-11-11): at the mic's 14.5px it still looked bigger, because it is twice as wide and has
// more ink. Level changes fade (250 ms).
Item {
    id: w

    property int level: 4
    property color color: Theme.color3
    property bool slashed: false
    property real size: 13
    readonly property color dim: Qt.rgba(color.r, color.g, color.b, 0.28)
    readonly property real k: size / 16          // geometry below is designed at 16px

    implicitWidth: Math.round(20 * k)
    implicitHeight: Math.round(size)

    readonly property real cx: width / 2
    readonly property real cy: height - 1.5 * k

    Rectangle {
        width: 4 * w.k
        height: width
        radius: width / 2
        x: w.cx - width / 2
        y: w.cy - 3 * w.k
        color: w.level >= 1 ? w.color : w.dim
        Behavior on color { ColorAnimation { duration: Theme.animNormal } }
    }

    Repeater {
        model: 3

        Shape {
            id: arc
            required property int index
            property color stroke: w.level >= index + 2 ? w.color : w.dim
            Behavior on stroke { ColorAnimation { duration: Theme.animNormal } }

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: arc.stroke
                strokeWidth: 2.2 * w.k
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: w.cx
                    centerY: w.cy - w.k
                    radiusX: (5 + arc.index * 4.5) * w.k
                    radiusY: radiusX
                    startAngle: 225
                    sweepAngle: 90
                    moveToStart: true
                }
            }
        }
    }

    Shape {
        visible: w.slashed
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: w.color
            strokeWidth: 2.2 * w.k
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 3 * w.k
            startY: w.k
            PathLine { x: w.width - 3 * w.k; y: w.height - w.k }
        }
    }
}
