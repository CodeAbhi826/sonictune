// components/LyricsView.qml — synced lyrics, centered and highlighted at
// the current playback position.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: lyricsView
    color: "transparent"

    property var lines: []
    property int currentPositionMs: 0
    property string currentTrackTitle: ""
    property string currentTrackArtist: ""
    property string currentTrackAlbum: ""
    property int currentTrackDurationMs: 0
    property int activeIndex: -1

    Connections {
        target: Daemon
        function onLyricsReceived(l) {
            lyricsView.lines = l || []
            lyricsView._updateActive()
        }
    }

    function fetchLyrics() {
        if (!lyricsView.currentTrackTitle) return
        lyricsView.lines = []
        lyricsView.activeIndex = -1
        Daemon.getLyrics(
            lyricsView.currentTrackTitle,
            lyricsView.currentTrackArtist,
            lyricsView.currentTrackAlbum,
            lyricsView.currentTrackDurationMs
        )
    }

    function _updateActive() {
        var newActive = -1
        for (var i = 0; i < lyricsView.lines.length; i++) {
            if (lyricsView.lines[i].time_ms <= lyricsView.currentPositionMs) {
                newActive = i
            } else {
                break
            }
        }
        if (newActive !== lyricsView.activeIndex) {
            lyricsView.activeIndex = newActive
            if (lyricsView.activeIndex >= 0) {
                listView.positionViewAtIndex(lyricsView.activeIndex, ListView.Center)
            }
        }
    }

    onCurrentTrackTitleChanged: fetchLyrics()
    onCurrentPositionMsChanged: _updateActive()

    ListView {
        id: listView
        anchors.fill: parent
        anchors.margins: Theme.spacingXl
        clip: true
        model: lyricsView.lines
        spacing: Theme.spacingSm
        interactive: true
        visible: lyricsView.lines.length > 0

        delegate: Text {
            id: lyricLine
            required property var modelData
            required property int index

            width: listView.width
            text: modelData.text
            color: index === lyricsView.activeIndex ? Theme.primary : Theme.onSurfaceVariant
            font: index === lyricsView.activeIndex ? Theme.fontTitleLarge : Theme.fontBodyLarge
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap

            Behavior on color { ColorAnimation { duration: Theme.durationBase } }

            opacity: Math.max(0.3, 1 - Math.abs(index - lyricsView.activeIndex) * 0.15)
            Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (lyricLine.modelData.time_ms > 0) {
                        Daemon.seek(lyricLine.modelData.time_ms)
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: lyricsView.lines.length === 0
        spacing: Theme.spacingSm

        Icon { Layout.alignment: Qt.AlignHCenter; name: "note"; size: 28; color: Theme.onSurfaceVariant }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: lyricsView.currentTrackTitle
                ? qsTr("No lyrics found for \"%1\"").arg(lyricsView.currentTrackTitle)
                : qsTr("Nothing playing")
            color: Theme.onSurfaceVariant
            font: Theme.fontTitleMedium
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
