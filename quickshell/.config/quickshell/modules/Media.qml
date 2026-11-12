import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs
import qs.components

// Centre group [prev | album art | media title | next]. Replaces Waybar custom/prev,
// image#album-art, custom/mediaplayer, custom/next plus scripts/mediaplayer.sh and
// mediaplayer.css (the 101 perc classes are the progress fill in the title's underlay).
//
// Only the spotifast MPRIS player counts. Without it (or when it is stopped / has no track)
// the art and title segments collapse to zero width (animated by Segment), so only
// [prev | next] remain, like Waybar where the empty custom module and image are hidden.
PillGroup {
    id: root

    // Max width of the whole group. The shell sets it to the free centre space; if the group
    // would not fit, the media title elides by width (keeps at least 30px).
    property real maxWidth: 1e9

    readonly property MprisPlayer player: Mpris.players.values.find(p => (p?.dbusName ?? "").startsWith("org.mpris.MediaPlayer2.spotifast")) ?? null

    readonly property bool active: player !== null && player.playbackState !== MprisPlaybackState.Stopped && player.trackTitle !== ""
    readonly property bool playing: active && player.isPlaying

    readonly property real progress: active && player.length > 0 ? Math.max(0, Math.min(1, player.position / player.length)) : 0

    // mediaplayer.sh: status Playing shows  (pause glyph), anything else  (play glyph).
    readonly property string playIcon: playing ? "" : ""
    // mediaplayer.sh text: "$icon $title - $artist" (Waybar max-length 20 counts the icon too).
    readonly property string mediaText: active ? playIcon + " " + player.trackTitle + " - " + player.trackArtist : ""
    // mediaplayer.sh tooltip: title, artist, album on separate lines (no click hints).
    readonly property string mediaTooltip: active ? player.trackTitle + "\n" + player.trackArtist + "\n" + player.trackAlbum : ""

    readonly property string artUrl: active ? player.trackArtUrl : ""

    // `position` is not reactive: re-read it once a second, only while playing.
    Timer {
        running: root.playing
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player.positionChanged()
    }

    // ---- custom/prev --------------------------------------------------------------------
    Segment {
        id: prevSeg
        leftPadding: 13
        rightPadding: 13
        tooltip: "Previous"
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton && root.player?.canGoPrevious)
                root.player.previous();
        }

        BarText {
            anchors.verticalCenter: parent.verticalCenter
            text: String.fromCodePoint(0xf04ae)
        }
    }

    // ---- image#album-art ----------------------------------------------------------------
    Segment {
        id: artSeg

        // The art shows once an image is actually loaded (mediaplayer.sh removes the file
        // when there is no URL or the download fails, which hides Waybar's image module).
        readonly property bool shown: root.artUrl !== "" && (artSeg._artA ? artA : artB).status === Image.Ready

        leftPadding: 0
        rightPadding: 0
        contentWidth: shown ? 40 : 0
        visible: implicitWidth > 0.5
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                Run.dispatch("hl.dsp.focus({ workspace = 9 })");
        }

        // Cross-fade: new art loads into the hidden Image; swap once it is Ready (or failed),
        // so the old cover stays until the new one can replace it (no blank flash).
        property bool _artA: true

        function _load(): void {
            if (root.artUrl === "")
                return;
            const next = _artA ? artB : artA;
            const cur = _artA ? artA : artB;
            if (cur.source.toString() === root.artUrl)
                return;
            if (next.source.toString() !== root.artUrl)
                next.source = root.artUrl;
            _trySwap();
        }

        function _trySwap(): void {
            const next = _artA ? artB : artA;
            if (root.artUrl !== "" && next.source.toString() === root.artUrl
                    && (next.status === Image.Ready || next.status === Image.Error))
                _artA = !_artA;
        }

        Connections {
            target: root
            function onArtUrlChanged() { artSeg._load(); }
        }
        Component.onCompleted: artA.source = root.artUrl

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            // style.css #image:hover
            opacity: artSeg.hovered ? 0.75 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

            Image {
                id: artA
                anchors.fill: parent
                sourceSize: Qt.size(80, 80)
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                opacity: artSeg._artA ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                onStatusChanged: artSeg._trySwap()
            }

            Image {
                id: artB
                anchors.fill: parent
                sourceSize: Qt.size(80, 80)
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                opacity: artSeg._artA ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                onStatusChanged: artSeg._trySwap()
            }
        }
    }

    // ---- custom/mediaplayer -------------------------------------------------------------
    Segment {
        id: titleSeg

        leftPadding: root.active ? Theme.pillPadding : 0
        rightPadding: root.active ? Theme.pillPadding : 0
        contentWidth: root.active ? title.implicitWidth : 0
        visible: implicitWidth > 0.5
        tooltip: root.mediaTooltip
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton && root.player?.canTogglePlaying)
                root.player.togglePlaying();
        }

        // Progress (mediaplayer.css): fill from the left over the track colour.
        // shownProgress follows root.progress: a normal 1 s tick glides linearly over the
        // tick; seeks, track changes and pauses use a short OutCubic instead. Steps under
        // 2 px are set directly: animating them looks the same but would redraw every frame.
        property real shownProgress: 0

        NumberAnimation {
            id: progressAnim
            target: titleSeg
            property: "shownProgress"
        }

        Connections {
            target: root
            function onProgressChanged() {
                const to = root.progress;
                const from = titleSeg.shownProgress;
                const deltaSec = (to - from) * (root.player?.length ?? 0);
                const deltaPx = Math.abs(to - from) * titleSeg.width;
                progressAnim.stop();
                if (deltaPx < 2) {
                    titleSeg.shownProgress = to;
                    return;
                }
                const tick = root.playing && deltaSec > 0 && deltaSec < 2.5;
                progressAnim.from = from;
                progressAnim.to = to;
                progressAnim.duration = tick ? 1000 : Theme.animNormal;
                progressAnim.easing.type = tick ? Easing.Linear : Easing.OutCubic;
                progressAnim.start();
            }
        }

        underlay: Rectangle {
            anchors.fill: parent
            color: Theme.progressTrack

            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: parent.width * Math.max(0, Math.min(1, titleSeg.shownProgress))
                color: Theme.progressFill
            }
        }

        FancyText {
            id: title
            anchors.verticalCenter: parent.verticalCenter
            text: root.mediaText
            maxChars: 20
            // Everything else in the group (segments, row spacing, border) is subtracted.
            maxWidth: Math.max(30, root.maxWidth - prevSeg.width - artSeg.width - nextSeg.width
                               - 5 * Theme.pillBorder - titleSeg.leftPadding - titleSeg.rightPadding)
            hovered: titleSeg.hovered
            opacity: root.active ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        }
    }

    // ---- custom/next --------------------------------------------------------------------
    Segment {
        id: nextSeg
        leftPadding: 13
        rightPadding: 13
        tooltip: "Next"
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton && root.player?.canGoNext)
                root.player.next();
        }

        BarText {
            anchors.verticalCenter: parent.verticalCenter
            text: String.fromCodePoint(0xf04ad)
        }
    }
}
