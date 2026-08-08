// components/NowPlayingBar.qml — persistent bottom player bar (Material 3 Dark).
// Full-width, anchored to window bottom. Click album art opens NowPlayingPage.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: nowPlayingBar
    height: 80
    color: Theme.playerBarBg
    border.width: 1
    border.color: Theme.playerBarBorder

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
            nowPlayingBar.currentTrack = track || {}
        }
        function onPositionChanged(pos, dur) {
            nowPlayingBar.positionMs = pos
            nowPlayingBar.durationMs = dur
        }
        function onStateChanged(state) {
            nowPlayingBar.isPlaying = state === "playing"
        }
        function onStatusReceived(s) {
            nowPlayingBar.status = s || {}
            nowPlayingBar.isPlaying = s.state === "playing"
            nowPlayingBar.positionMs = s.position_ms || 0
            nowPlayingBar.durationMs = s.duration_ms || 0
            if (s.track) nowPlayingBar.currentTrack = s.track
        }
        function onQueueChanged() {
            Daemon.getStatus()
        }
    }

    Component.onCompleted: Daemon.getStatus()

    function trackField(t, camel, snake) {
        if (!t) return ""
        if (t[camel] !== undefined) return t[camel]
        if (t[snake] !== undefined) return t[snake]
        return ""
    }

    readonly property string thumbUrl: trackField(currentTrack, "thumbnailUrl", "thumbnail_url")

    function artSource() {
        return thumbUrl ? "image://art/" + encodeURIComponent(thumbUrl) : ""
    }

    function formatTime(ms) {
        return Theme.formatDurationShort(ms)
    }

    function volumeIconName() {
        var v = status.volume === undefined ? 80 : status.volume
        if (v === 0) return "volumeMute"
        if (v < 33) return "volumeLow"
        if (v < 66) return "volumeMed"
        return "volumeHigh"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space4
        anchors.rightMargin: Theme.space4
        spacing: Theme.space4

        // --- Album art (click opens Now Playing) ----------------------
        Item {
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd
                color: Theme.surfaceContainer
                clip: true

                Image {
                    anchors.fill: parent
                    cache: false
                    source: nowPlayingBar.artSource()
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Icon {
                    anchors.centerIn: parent
                    visible: nowPlayingBar.thumbUrl === ""
                    name: "musicNote"
                    size: 24
                    color: Theme.fgSurfaceVariant
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: nowPlayingBar.openNowPlaying()
            }
        }

        // --- Title / artist + seek row --------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: currentTrack.title || qsTr("Nothing playing")
                color: Theme.fgSurface
                font: Theme.fontTitleMedium
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: currentTrack.artist || qsTr("Pick something to play")
                color: Theme.fgSurfaceVariant
                font: Theme.fontBodySmall
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space2

                STSlider {
                    id: seekSlider
                    Layout.fillWidth: true
                    from: 0
                    to: Math.max(1, durationMs)
                    value: Math.min(positionMs, durationMs)
                    enabled: durationMs > 0
                    opacity: durationMs > 0 ? 1.0 : 0.3
                    onMoved: Daemon.seek(value)
                }

                Text {
                    text: Theme.formatDurationShort(positionMs)
                    color: Theme.fgSurfaceVariant
                    font: Theme.fontMono
                }

                Text {
                    text: "/" + Theme.formatDuration(durationMs)
                    color: Theme.fgSurfaceVariant
                    font: Theme.fontMono
                }
            }
        }

        // --- Transport + volume + queue -------------------------------
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.space2

            IconButton {
                iconName: "shuffle"
                iconSize: 18
                toolTip: qsTr("Shuffle")
                checkable: true
                checked: status.shuffle === true
                onClicked: Daemon.setShuffle(!status.shuffle)
            }

            IconButton {
                iconName: "previous"
                iconSize: 20
                toolTip: qsTr("Previous")
                onClicked: Daemon.previous()
            }

            Rectangle {
                width: 48
                height: 48
                radius: width / 2
                color: Theme.primary
                scale: playArea.pressed ? 0.94 : 1.0
                Behavior on scale {
                    enabled: !Theme.reducedMotion
                    NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic }
                }

                Icon {
                    anchors.centerIn: parent
                    name: (isPlaying && status.state === "playing" && currentTrack.title) ? "pause" : "play"
                    size: 24
                    color: Theme.fgPrimary
                }

                MouseArea {
                    id: playArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Daemon.playPause()
                }
            }

            IconButton {
                iconName: "next"
                iconSize: 20
                toolTip: qsTr("Next")
                onClicked: Daemon.next()
            }

            IconButton {
                property string mode: status.repeat || "off"
                iconName: mode === "one" ? "repeatOne" : "repeat"
                iconSize: 18
                toolTip: qsTr("Repeat")
                checkable: true
                checked: mode !== "off"
                onClicked: {
                    var next = mode === "off" ? "all" : mode === "all" ? "one" : "off"
                    Daemon.setRepeat(next)
                }
            }

            IconButton {
                iconName: volumeIconName()
                iconSize: 18
                toolTip: qsTr("Volume")
                onClicked: volumeSliderBox.visible = !volumeSliderBox.visible
            }

            STSlider {
                id: volumeSliderBox
                Layout.preferredWidth: 100
                visible: false
                from: 0
                to: 100
                value: status.volume === undefined ? 80 : status.volume
                onMoved: Daemon.setVolume(Math.round(value))
            }

            IconButton {
                iconName: "picture_in_picture"
                iconSize: 18
                toolTip: qsTr("Now Playing")
                onClicked: nowPlayingBar.openNowPlaying()
            }

            IconButton {
                iconName: "queue"
                iconSize: 18
                toolTip: qsTr("Queue")
                onClicked: nowPlayingBar.queueRequested()
            }
        }
    }
}