import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// The bar's one shared tooltip (put one inside each bar window: `TooltipHost { bar: bar }`).
// It shows TooltipState.target/text (or a component instance, TooltipState.component, e.g. the
// calendar) when the target is on this bar. Content padding: 12px left/right, 8px top/bottom.
//
// Motion (user decisions 2026-11-09/11):
//  - open:  the box starts at the pill's width, hidden behind the pill's bottom edge, then slides
//           down `gap` px below it while growing to its own width and fading in (220 ms OutCubic);
//  - glide: when the target changes while open, the box moves and resizes to the new pill and the
//           text cross-fades (220 ms OutCubic);
//  - close: it shrinks back into the pill and slides up (150 ms InCubic).
// The box is centred under its pill and kept at least `gap` from the screen edges. Its start/end width is the pill's
// width minus the corner radius on both sides.
// It is drawn on its own overlay layer surface under the bar (fixed size, click-through with
// an empty mask), which is unmapped only after the close animation.
Item {
    id: host

    required property var bar      // the PanelWindow this host belongs to
    property int gap: 8
    property int maxHeight: 400    // popup surface height; grows if a tooltip needs more

    // Box geometry in tooltip-surface coordinates (x = bar x, y 0 = bar bottom).
    property real boxX: 0
    property real boxY: 0
    property real boxWidth: 0
    property real boxHeight: 0
    property real boxOpacity: 0

    property bool mapped: false
    property bool isOpen: false
    property Item shownTarget: null

    // Animation mode, set before the values change (Behaviors read it when they start).
    property bool animate: false
    property int duration: 220
    property int easing: Easing.OutCubic

    property bool _useA: true

    visible: false

    function measure(txt: string): size {
        measureText.text = txt;
        return Qt.size(measureText.implicitWidth + 24, measureText.implicitHeight + 16);
    }

    // Content slots (A/B) for the cross-fade. Each shows either text or a component instance.
    readonly property Item activeItem: _useA ? loaderA.item : loaderB.item

    function slotSize(useA: bool): size {
        const item = useA ? loaderA.item : loaderB.item;
        if (item)
            return Qt.size(item.implicitWidth + 24, item.implicitHeight + 16);
        return measure(useA ? labelA.text : labelB.text);
    }

    // Start/end extent of the box at pill `t`: the pill's width minus its corner radius on both
    // sides, so the box seems to come out of the straight part of the pill's bottom edge
    // (never narrower than one full rounded end, 2 * radius).
    function pillExtent(t: Item): var {
        const p = t.mapToItem(null, 0, 0);
        const r = Theme.pillRadius;
        const w = Math.max(2 * r, t.width - 2 * r);
        return { x: p.x + (t.width - w) / 2, width: w };
    }

    // Where the box goes for target `t` with size `s`: centred under the pill, but at least
    // `gap` (the distance to the pill above) from the screen edges (user decision 2026-11-11),
    // plus the pill's extent.
    function geometryFor(t: Item, s: size): var {
        const p = t.mapToItem(null, 0, 0);
        const centred = p.x + t.width / 2 - s.width / 2;
        const x = Math.max(host.gap, Math.min(host.bar.width - host.gap - s.width, centred));
        const e = pillExtent(t);
        return { x: x, pillX: e.x, pillWidth: e.width };
    }

    // Puts the content into a slot (A without cross-fade, else the hidden one) and makes it the
    // shown slot. Returns its box size (content + padding).
    function setContent(txt: string, comp: Component, crossfade: bool): size {
        const useA = crossfade ? !_useA : true;
        const label = useA ? labelA : labelB;
        const loader = useA ? loaderA : loaderB;
        label.text = comp ? "" : txt;
        loader.sourceComponent = comp;
        _useA = useA;
        return slotSize(useA);
    }

    // The shown content changed size by itself (e.g. calendar month): resize smoothly.
    function refit(): void {
        if (!isOpen || !shownTarget)
            return;
        const s = slotSize(_useA);
        const g = geometryFor(shownTarget, s);
        duration = 220;
        easing = Easing.OutCubic;
        animate = true;
        boxX = g.x;
        boxWidth = s.width;
        boxHeight = s.height;
    }

    function sync(): void {
        const t = TooltipState.target;
        const mine = TooltipState.active && t !== null && t.Window.window === host.Window.window;
        if (mine)
            show(t, TooltipState.text, TooltipState.component);
        else if (isOpen)
            close();
    }

    function show(t: Item, txt: string, comp: Component): void {
        closeTimer.stop();
        const s = setContent(txt, comp, isOpen);
        const g = geometryFor(t, s);
        if (s.height + 2 * gap > maxHeight)
            maxHeight = s.height + 2 * gap;

        if (!isOpen) {
            // Start: pill-sized, hidden behind the pill's bottom edge.
            animate = false;
            boxX = g.pillX;
            boxWidth = g.pillWidth;
            boxHeight = s.height;
            boxY = -s.height;
            boxOpacity = 0;
            mapped = true;
            isOpen = true;
            shownTarget = t;
            duration = 220;
            easing = Easing.OutCubic;
            animate = true;
            boxX = g.x;
            boxWidth = s.width;
            boxY = gap;
            boxOpacity = 1;
            return;
        }

        // Glide (new target) or resize (same target, new text).
        duration = 220;
        easing = Easing.OutCubic;
        animate = true;
        shownTarget = t;
        boxX = g.x;
        boxWidth = s.width;
        boxHeight = s.height;
        boxY = gap;
        boxOpacity = 1;
    }

    function close(): void {
        isOpen = false;
        duration = 150;
        easing = Easing.InCubic;
        animate = true;
        const t = shownTarget;
        if (t) {
            const e = pillExtent(t);
            boxX = e.x;
            boxWidth = e.width;
        }
        boxY = -boxHeight;
        boxOpacity = 0;
        closeTimer.restart();
    }

    Connections {
        target: host.activeItem
        ignoreUnknownSignals: true
        function onImplicitWidthChanged() {
            host.refit();
        }
        function onImplicitHeightChanged() {
            host.refit();
        }
    }

    Connections {
        target: TooltipState
        function onRevisionChanged() {
            host.sync();
        }
    }

    Timer {
        id: closeTimer
        interval: 170
        onTriggered: {
            if (host.isOpen)
                return;
            host.mapped = false;
            // Free component instances (e.g. the calendar) while hidden.
            loaderA.sourceComponent = null;
            loaderB.sourceComponent = null;
        }
    }

    // Measures text with the tooltip font without showing it.
    BarText {
        id: measureText
        visible: false
        textFormat: Text.PlainText
    }

    // A layer-shell surface right under the bar, not an xdg PopupWindow: Hyprland drew the popup
    // 4px right of its requested position, so tooltips at the screen edge overshot their margin.
    // Layer surfaces are placed exactly. Ignore = not pushed down by the bar's exclusive zone.
    PanelWindow {
        screen: host.bar.screen
        anchors {
            top: true
            left: true
            right: true
        }
        margins.top: host.bar.height
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-tooltip"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        implicitHeight: host.maxHeight
        color: "transparent"
        visible: host.mapped
        mask: Region {}

        // Clips at the bar's bottom edge (= the pills' bottom edge), so the box seems to come
        // out from behind the pill.
        Item {
            anchors.fill: parent
            clip: true

            Item {
                id: box

                x: host.boxX
                y: host.boxY
                width: host.boxWidth
                height: host.boxHeight
                opacity: host.boxOpacity

                Behavior on x { enabled: host.animate; NumberAnimation { duration: host.duration; easing.type: host.easing } }
                Behavior on y { enabled: host.animate; NumberAnimation { duration: host.duration; easing.type: host.easing } }
                Behavior on width { enabled: host.animate; NumberAnimation { duration: host.duration; easing.type: host.easing } }
                Behavior on height { enabled: host.animate; NumberAnimation { duration: host.duration; easing.type: host.easing } }
                Behavior on opacity { enabled: host.animate; NumberAnimation { duration: host.duration; easing.type: host.easing } }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.pillRadius
                    color: Theme.background
                    border.width: Theme.pillBorder
                    border.color: Theme.color5
                    opacity: 0.9
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: Theme.pillBorder
                    clip: true

                    Item {
                        anchors.fill: parent
                        opacity: host._useA ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                        BarText {
                            id: labelA
                            x: (parent.width - implicitWidth) / 2
                            anchors.verticalCenter: parent.verticalCenter
                            textFormat: Text.PlainText
                        }
                        Loader {
                            id: loaderA
                            x: (parent.width - implicitWidth) / 2
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Item {
                        anchors.fill: parent
                        opacity: host._useA ? 0 : 1
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

                        BarText {
                            id: labelB
                            x: (parent.width - implicitWidth) / 2
                            anchors.verticalCenter: parent.verticalCenter
                            textFormat: Text.PlainText
                        }
                        Loader {
                            id: loaderB
                            x: (parent.width - implicitWidth) / 2
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }
}
