// components/WaveformSeekBar.qml — the app's signature transport control.
//
// A stylized, deterministic bar pattern (NOT a literal audio waveform —
// there's no waveform analysis happening) that fills with the accent color
// up to the current playback position, in place of a plain slider track.
// Height per bar is derived from a hash of the track id + bar index, so
// it's stable for a given track (same look every time you play it) and
// varies from track to track, which reads as much more "instrumented"
// than a flat progress line while staying honest about being decorative.

pragma ComponentBehavior: Bound

import QtQuick
import "../theme"

Item {
    id: root

    property int positionMs: 0
    property int durationMs: 0
    property string trackKey: ""
    property real barWidth: 3
    property real barSpacing: 2
    property real minHeightFraction: 0.22
    property bool hovered: hoverHandler.hovered || dragArea.pressed

    // Assigning (not re-declaring) the inherited Item.enabled property —
    // this also gets us Qt Quick's normal "disabled items don't receive
    // input" behavior for free, rather than only cosmetically dimming.
    enabled: durationMs > 0

    signal seekRequested(int ms)

    implicitHeight: 32

    readonly property int barCount: Math.max(8, Math.floor(width / (barWidth + barSpacing)))
    readonly property real progress: durationMs > 0 ? Math.min(1, Math.max(0, positionMs / durationMs)) : 0

    Row {
        anchors.centerIn: parent
        spacing: root.barSpacing

        Repeater {
            model: root.barCount

            delegate: Rectangle {
                id: bar
                required property int index

                readonly property real h: root._barHeight(index)
                readonly property real filledUpTo: root.barCount > 1 ? index / (root.barCount - 1) : 0

                width: root.barWidth
                height: Math.max(3, h * root.height)
                anchors.bottom: parent.bottom
                radius: width / 2
                color: !root.enabled
                    ? Theme.outlineStrong
                    : (filledUpTo <= root.progress ? Theme.primary : Theme.outlineStrong)
                opacity: !root.enabled ? 0.5 : (filledUpTo <= root.progress ? 1.0 : 0.55)

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                Behavior on height {
                    enabled: !dragArea.pressed
                    NumberAnimation { duration: Theme.durationBase; easing.type: Theme.easingStandard }
                }
            }
        }
    }

    function _barHeight(i) {
        var str = root.trackKey + ":" + i
        var seed = 7
        for (var c = 0; c < str.length; c++) {
            seed = (seed * 31 + str.charCodeAt(c)) % 2147483647
        }
        var v = (Math.abs(seed) % 1000) / 1000
        return root.minHeightFraction + v * (1 - root.minHeightFraction)
    }

    HoverHandler { id: hoverHandler }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: function(mouse) { _seekToX(mouse.x) }
        onPositionChanged: function(mouse) { if (pressed) _seekToX(mouse.x) }

        function _seekToX(x) {
            var frac = Math.min(1, Math.max(0, x / width))
            root.seekRequested(Math.round(frac * root.durationMs))
        }
    }
}
