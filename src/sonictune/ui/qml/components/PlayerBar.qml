// components/PlayerBar.qml — persistent transport bar at the bottom of the
// window: art + track info (click to open Now Playing), transport
// controls with the waveform seek bar, volume, and queue access.

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: playerBar
    color: Theme.surface

    signal queueRequested()
    signal openNowPlaying()

    property var status: ({})
    property var currentTrack: ({})
    property int positionMs: 0
    property int durationMs: 0
    property bool isPlaying: false

    Connections {
        target: Daemon
        function onTrackChanged(track) {
            playerBar.currentTrack = track || {}
        }
        function onPositionChanged(pos, dur) {
            playerBar.positionMs = pos
            playerBar.durationMs = dur
        }
        function onStateChanged(state) {
            playerBar.isPlaying = state === "playing"
        }
        function onStatusReceived(s) {
            playerBar.status = s || {}
            playerBar.isPlaying = s.state === "playing"
            playerBar.positionMs = s.position_ms || 0
            playerBar.durationMs = s.duration_ms || 0
            if (s.track) playerBar.currentTrack = s.track
        }
        function onQueueChanged() {
            Daemon.getStatus()
        }
    }

    Component.onCompleted: Daemon.getStatus()

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingMd
        anchors.rightMargin: Theme.spacingMd
        spacing: Theme.spacingLg

        // --- Track info (click to open Now Playing) -------------------
        Item {
            Layout.preferredWidth: 260
            Layout.maximumWidth: 300
            Layout.fillHeight: true

            RowLayout {
                anchors.fill: parent
                spacing: Theme.spacingSm

                Rectangle {
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56
                    radius: Theme.radiusMd
                    color: Theme.surfaceContainer
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: playerBar.currentTrack.thumbnail_url
                            ? "image://art/" + encodeURIComponent(playerBar.currentTrack.thumbnail_url)
                            : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    Icon {
                        anchors.centerIn: parent
                        visible: !playerBar.currentTrack.thumbnail_url
                        name: "note"
                        size: 20
                        color: Theme.onSurfaceVariant
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: playerBar.currentTrack.title || qsTr("Nothing playing")
                        color: Theme.onSurface
                        font: Theme.fontTitleMedium
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: playerBar.currentTrack.artist || qsTr("Pick something in Search or your Library")
                        color: Theme.onSurfaceVariant
                        font: Theme.fontBodySmall
                        elide: Text.ElideRight
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: playerBar.openNowPlaying()
            }
        }

        // --- Transport + seek -------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.spacingSm

                IconButton {
                    icon: "shuffle"
                    diameter: 30
                    iconSize: 14
                    highlighted: playerBar.status.shuffle === true
                    onClicked: Daemon.setShuffle(!playerBar.status.shuffle)
                }
                IconButton {
                    icon: "previous"
                    diameter: 34
                    iconSize: 16
                    onClicked: Daemon.previous()
                }
                IconButton {
                    icon: playerBar.isPlaying ? "pause" : "play"
                    diameter: 44
                    iconSize: 18
                    prominent: true
                    onClicked: Daemon.playPause()
                }
                IconButton {
                    icon: "next"
                    diameter: 34
                    iconSize: 16
                    onClicked: Daemon.next()
                }
                IconButton {
                    property string mode: playerBar.status.repeat || "off"
                    icon: mode === "one" ? "repeatOne" : "repeat"
                    diameter: 30
                    iconSize: 14
                    highlighted: mode !== "off"
                    onClicked: {
                        var next = mode === "off" ? "all" : mode === "all" ? "one" : "off"
                        Daemon.setRepeat(next)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: 640
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.spacingSm

                Text {
                    text: playerBar.formatTime(playerBar.positionMs)
                    color: Theme.onSurfaceVariant
                    font: Theme.fontMono
                    Layout.preferredWidth: 40
                }

                WaveformSeekBar {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    positionMs: playerBar.positionMs
                    durationMs: playerBar.durationMs
                    trackKey: playerBar.currentTrack.video_id || ""
                    barWidth: 2.5
                    barSpacing: 2
                    onSeekRequested: function(ms) { Daemon.seek(ms) }
                }

                Text {
                    text: playerBar.formatTime(playerBar.durationMs)
                    color: Theme.onSurfaceVariant
                    font: Theme.fontMono
                    Layout.preferredWidth: 40
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        // --- Volume + queue ----------------------------------------------
        RowLayout {
            Layout.preferredWidth: 190
            spacing: Theme.spacingSm

            Icon {
                name: playerBar.volumeIconName()
                size: 16
                color: Theme.onSurfaceVariant
            }

            Slider {
                id: volumeSlider
                Layout.preferredWidth: 90
                from: 0
                to: 100
                value: playerBar.status.volume || 80
                onMoved: Daemon.setVolume(Math.floor(value))

                background: Rectangle {
                    x: volumeSlider.leftPadding
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: volumeSlider.availableWidth
                    height: 3
                    radius: 1.5
                    color: Theme.outlineStrong

                    Rectangle {
                        width: volumeSlider.visualPosition * parent.width
                        height: parent.height
                        radius: parent.radius
                        color: Theme.onSurfaceVariant
                    }
                }

                handle: Rectangle {
                    x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: 10
                    height: 10
                    radius: 5
                    color: Theme.onSurface
                }
            }

            Item { Layout.fillWidth: true }

            IconButton {
                icon: "queue"
                diameter: 34
                iconSize: 15
                onClicked: playerBar.queueRequested()
            }
        }
    }

    function formatTime(ms) {
        if (!ms || ms <= 0) return "0:00"
        var s = Math.floor(ms / 1000)
        var m = Math.floor(s / 60)
        s = s % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    function volumeIconName() {
        var v = playerBar.status.volume === undefined ? 80 : playerBar.status.volume
        if (v === 0) return "volumeMute"
        if (v < 33) return "volumeLow"
        if (v < 66) return "volumeMed"
        return "volumeHigh"
    }
}
