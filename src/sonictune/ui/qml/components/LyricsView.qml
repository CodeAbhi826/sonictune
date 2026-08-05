// components/LyricsView.qml — synced lyrics, centered and highlighted at
// the current playback position (Material 3 Dark).

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

    // Spec-facing aliases — kept in sync with the legacy names above.
    property var model: []
    property int currentTimeMs: 0

    onLinesChanged: lyricsView.model = lyricsView.lines
    onCurrentPositionMsChanged: {
        lyricsView.currentTimeMs = lyricsView.currentPositionMs
        lyricsView._updateActive()
    }

    Connections {
        target: Daemon
        function onLyricsReceived(l) {
            lyricsView.lines = l || []
            lyricsView._updateActive()
        }
        function onLyricsError(err) {
            lyricsView.lines = []
            lyricsView.activeIndex = -1
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

    function _lineTime(l) {
        if (!l) return 0
        if (l.timeMs !== undefined) return l.timeMs
        if (l.time_ms !== undefined) return l.time_ms
        return 0
    }

    function _updateActive() {
        var ls = lyricsView.lines || []
        var newActive = -1
        for (var i = 0; i < ls.length; i++) {
            if (lyricsView._lineTime(ls[i]) <= lyricsView.currentPositionMs) {
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

    ListView {
        id: listView
        anchors.fill: parent
        anchors.margins: Theme.space8
        clip: true
        model: lyricsView.lines
        spacing: Theme.space3
        interactive: true
        visible: (lyricsView.lines || []).length > 0
        cacheBuffer: Theme.listCacheBuffer

        delegate: Text {
            id: lyricLine
            required property var modelData
            required property int index

            width: listView.width
            text: modelData.text || ""
            color: index === lyricsView.activeIndex ? Theme.primary : Theme.fgSurface
            font: index === lyricsView.activeIndex ? Theme.fontTitleLarge : Theme.fontBodyLarge
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap

            Behavior on color {
                enabled: !Theme.reducedMotion
                ColorAnimation { duration: Theme.durNormal }
            }

            opacity: Math.max(0.45, 1 - Math.abs(index - lyricsView.activeIndex) * 0.15)
            Behavior on opacity {
                enabled: !Theme.reducedMotion
                NumberAnimation { duration: Theme.durNormal }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var t = lyricsView._lineTime(lyricLine.modelData)
                    if (t > 0) Daemon.seek(t)
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: (lyricsView.lines || []).length === 0
        spacing: Theme.space2

        Icon {
            Layout.alignment: Qt.AlignHCenter
            name: "lyrics"
            size: 28
            color: Theme.fgSurfaceVariant
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("No lyrics found")
            color: Theme.fgSurface
            font: Theme.fontTitleMedium
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: lyricsView.currentTrackTitle !== ""
            text: qsTr("for \"%1\"").arg(lyricsView.currentTrackTitle)
            color: Theme.fgSurfaceVariant
            font: Theme.fontBodyMedium
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
