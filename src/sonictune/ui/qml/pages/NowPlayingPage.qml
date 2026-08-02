// pages/NowPlayingPage.qml — full now-playing view with large art,
// transport, and lyrics.
//
// BUGFIX: the shuffle/repeat buttons here used to read
// `nowPlayingPage.shuffle` / `nowPlayingPage.repeat`, properties that were
// never declared anywhere — always undefined, so the shuffle button always
// sent setShuffle(true) regardless of actual state and neither button ever
// visibly reflected the real queue state. Both are now backed by `status`,
// kept current via Daemon.statusReceived/getStatus(), same source of
// truth the PlayerBar uses.

import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"

Item {
    id: nowPlayingPage

    signal queueRequested()

    property var status: ({})
    property var currentTrack: ({})
    property int positionMs: 0
    property int durationMs: 0
    property bool isPlaying: false
    property bool showLyrics: false

    Connections {
        target: Daemon
        function onTrackChanged(track) { nowPlayingPage.currentTrack = track || {} }
        function onPositionChanged(pos, dur) { nowPlayingPage.positionMs = pos; nowPlayingPage.durationMs = dur }
        function onStateChanged(state) { nowPlayingPage.isPlaying = state === "playing" }
        function onStatusReceived(s) {
            nowPlayingPage.status = s || {}
            nowPlayingPage.isPlaying = s.state === "playing"
            nowPlayingPage.positionMs = s.position_ms || 0
            nowPlayingPage.durationMs = s.duration_ms || 0
            if (s.track) nowPlayingPage.currentTrack = s.track
        }
        function onQueueChanged() {
            Daemon.getStatus()
        }
    }

    Component.onCompleted: Daemon.getStatus()

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingXl
        spacing: Theme.spacingXl

        // --- Art + transport ---------------------------------------------
        ColumnLayout {
            Layout.preferredWidth: 380
            Layout.fillHeight: true
            spacing: Theme.spacingLg

            Item { Layout.fillHeight: true; Layout.preferredHeight: 1 }

            Rectangle {
                Layout.preferredWidth: 340
                Layout.preferredHeight: 340
                Layout.alignment: Qt.AlignHCenter
                radius: Theme.radiusLg
                color: Theme.surfaceContainer
                clip: true

                Image {
                    anchors.fill: parent
                    source: nowPlayingPage.currentTrack.thumbnail_url
                        ? "image://art/" + encodeURIComponent(nowPlayingPage.currentTrack.thumbnail_url)
                        : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Icon {
                    anchors.centerIn: parent
                    visible: !nowPlayingPage.currentTrack.thumbnail_url
                    name: "note"
                    size: 48
                    color: Theme.onSurfaceVariant
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: nowPlayingPage.currentTrack.title || qsTr("Nothing playing")
                    color: Theme.onSurface
                    font: Theme.fontHeadlineSmall
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    Layout.fillWidth: true
                    text: nowPlayingPage.currentTrack.artist || ""
                    color: Theme.onSurfaceVariant
                    font: Theme.fontBodyLarge
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingXs

                WaveformSeekBar {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    positionMs: nowPlayingPage.positionMs
                    durationMs: nowPlayingPage.durationMs
                    trackKey: nowPlayingPage.currentTrack.video_id || ""
                    barWidth: 3
                    barSpacing: 2.5
                    onSeekRequested: function(ms) { Daemon.seek(ms) }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: nowPlayingPage.formatTime(nowPlayingPage.positionMs); color: Theme.onSurfaceVariant; font: Theme.fontMono }
                    Item { Layout.fillWidth: true }
                    Text { text: nowPlayingPage.formatTime(nowPlayingPage.durationMs); color: Theme.onSurfaceVariant; font: Theme.fontMono }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.spacingMd

                IconButton {
                    icon: "shuffle"
                    diameter: 34
                    iconSize: 15
                    highlighted: nowPlayingPage.status.shuffle === true
                    onClicked: Daemon.setShuffle(!nowPlayingPage.status.shuffle)
                }
                IconButton {
                    icon: "previous"
                    diameter: 40
                    iconSize: 17
                    onClicked: Daemon.previous()
                }
                IconButton {
                    icon: nowPlayingPage.isPlaying ? "pause" : "play"
                    diameter: 56
                    iconSize: 22
                    prominent: true
                    onClicked: Daemon.playPause()
                }
                IconButton {
                    icon: "next"
                    diameter: 40
                    iconSize: 17
                    onClicked: Daemon.next()
                }
                IconButton {
                    property string mode: nowPlayingPage.status.repeat || "off"
                    icon: mode === "one" ? "repeatOne" : "repeat"
                    diameter: 34
                    iconSize: 15
                    highlighted: mode !== "off"
                    onClicked: {
                        var next = mode === "off" ? "all" : mode === "all" ? "one" : "off"
                        Daemon.setRepeat(next)
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.spacingLg
                Layout.topMargin: Theme.spacingSm

                Item {
                    implicitWidth: playerRow.implicitWidth
                    implicitHeight: playerRow.implicitHeight
                    Row {
                        id: playerRow
                        spacing: 6
                        Icon { name: "note"; size: 14; color: nowPlayingPage.showLyrics ? Theme.onSurfaceVariant : Theme.primary }
                        Text {
                            text: qsTr("Player")
                            color: nowPlayingPage.showLyrics ? Theme.onSurfaceVariant : Theme.primary
                            font: Theme.fontLabelLarge
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: nowPlayingPage.showLyrics = false }
                }

                Item {
                    implicitWidth: lyricsRow.implicitWidth
                    implicitHeight: lyricsRow.implicitHeight
                    Row {
                        id: lyricsRow
                        spacing: 6
                        Text {
                            text: qsTr("Lyrics")
                            color: nowPlayingPage.showLyrics ? Theme.primary : Theme.onSurfaceVariant
                            font: Theme.fontLabelLarge
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: nowPlayingPage.showLyrics = true }
                }

                IconButton {
                    icon: "queue"
                    diameter: 32
                    iconSize: 14
                    onClicked: nowPlayingPage.queueRequested()
                }
            }

            Item { Layout.fillHeight: true; Layout.preferredHeight: 1 }
        }

        Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Theme.outline; visible: nowPlayingPage.showLyrics }

        LyricsView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: nowPlayingPage.showLyrics
            currentPositionMs: nowPlayingPage.positionMs
            currentTrackTitle: nowPlayingPage.currentTrack.title || ""
            currentTrackArtist: nowPlayingPage.currentTrack.artist || ""
            currentTrackAlbum: nowPlayingPage.currentTrack.album || ""
            currentTrackDurationMs: nowPlayingPage.durationMs
        }
    }

    function formatTime(ms) {
        if (!ms || ms <= 0) return "0:00"
        var s = Math.floor(ms / 1000)
        var m = Math.floor(s / 60)
        s = s % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }
}
