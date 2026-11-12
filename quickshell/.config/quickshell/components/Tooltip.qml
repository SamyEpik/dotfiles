import QtQuick
import qs

// Asks the bar's shared tooltip (TooltipHost) to show `text` under `target`.
// Segment uses this for its `tooltip` property; modules normally don't use it directly.
//
// The first tooltip waits `delay` ms. While a tooltip is open (or hanging after the pointer
// left its pill), hovering another pill shows its tooltip at once and the host glides there.
QtObject {
    id: root

    required property Item target
    property string text: ""
    property Component component: null   // rich content instead of text
    readonly property bool hasContent: text !== "" || component !== null
    property bool show: false
    property int delay: 400

    property Timer _timer: Timer {
        interval: root.delay
        onTriggered: TooltipState.request(root.target, root.text, root.component)
    }

    onShowChanged: {
        if (show && hasContent) {
            if (TooltipState.active)
                TooltipState.request(target, text, component);
            else
                _timer.restart();
        } else {
            _timer.stop();
            TooltipState.release(target);
        }
    }

    function _changed(): void {
        if (!hasContent)
            TooltipState.drop(target);
        else
            TooltipState.update(target, text, component);
    }
    onTextChanged: _changed()
    onComponentChanged: _changed()

    Component.onDestruction: TooltipState.drop(target)
}
