// components/PlayerBar.qml — floating bottom player bar (Material 3 Dark).
// Rounded 16px corners, 1px border, album art + track info on the left
// (click opens Now Playing), title/artist + seek row in the middle, and
// transport + volume + queue on the right.

import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: playerBar
    radius: Theme.radiusLg
    color: Qt.rgba(Theme.playerBarBg.r, Theme.playerBarBg.g, Theme.playerBarBg.b, 0.88)
    border.width: 1
    border.color: Theme.playerBarBorder
    clip: true

    // Subtle glass highlight along the top edge.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: Qt.rgba(1, 1, 1, 0.10)
    }

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

    // --- Helpers ------------------------------------------------------
    function trackField(t, camel, snake) {
        if (!t) return ""
        if (t[camel] !== undefined) return t[camel]
        if (t[snake] !== undefined) return t[snake]
        return ""
    }

    readonly property string thumbUrl: playerBar.trackField(playerBar.currentTrack, "thumbnailUrl", "thumbnail_url")

    function artSource() {
        return playerBar.thumbUrl ? "image://art/" + encodeURIComponent(playerBar.thumbUrl) : ""
    }

    function formatTime(ms) {
        return Theme.formatDurationShort(ms)
    }

    function volumeIconName() {
        var v = playerBar.status.volume === undefined ? 80 : playerBar.status.volume
        if (v === 0) return "volumeMute"
        if (v < 33) return "volumeLow"
        if (v < 66) return "volumeMed"
        return "volumeHigh"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space3
        anchors.rightMargin: Theme.space3
        spacing: Theme.space3

        // --- Album art (click opens Now Playing) ----------------------
        Item {
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd
                color: Theme.surfaceContainer
                clip: true

                Image {
                    anchors.fill: parent
                    source: playerBar.artSource()
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Icon {
                    anchors.centerIn: parent
                    visible: playerBar.thumbUrl === ""
                    name: "musicNote"
                    size: 20
                    color: Theme.fgSurfaceVariant
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: playerBar.openNowPlaying()
            }
        }

        // --- Title / artist + seek row --------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: playerBar.currentTrack.title || qsTr("Nothing playing")
                color: Theme.fgSurface
                font: Theme.fontTitleMedium
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: playerBar.currentTrack.artist || qsTr("Pick something to play")
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
                    to: Math.max(1, playerBar.durationMs)
                    value: Math.min(playerBar.positionMs, playerBar.durationMs)
                    onMoved: Daemon.seek(value)
                }

                Text {
                    text: Theme.formatDurationShort(playerBar.positionMs)
                    color: Theme.fgSurfaceVariant
                    font: Theme.fontMono
                }

                Text {
                    text: "/" + Theme.formatDuration(playerBar.durationMs)
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
                checked: playerBar.status.shuffle === true
                onClicked: Daemon.setShuffle(!playerBar.status.shuffle)
            }

            IconButton {
                iconName: "previous"
                iconSize: 20
                toolTip: qsTr("Previous")
                onClicked: Daemon.previous()
            }

            Rectangle {
                width: 40
                height: 40
                radius: width / 2
                color: Theme.primary
                scale: playArea.pressed ? 0.94 : 1.0
                Behavior on scale {
                    enabled: !Theme.reducedMotion
                    NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic }
                }

                Icon {
                    anchors.centerIn: parent
                    name: playerBar.isPlaying ? "pause" : "play"
                    size: 22
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
                property string mode: playerBar.status.repeat || "off"
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
                iconName: playerBar.volumeIconName()
                iconSize: 18
                toolTip: qsTr("Volume")
                onClicked: volumeSliderBox.visible = !volumeSliderBox.visible
            }

            STSlider {
                id: volumeSliderBox
                Layout.preferredWidth: 80
                visible: false
                from: 0
                to: 100
                value: playerBar.status.volume === undefined ? 80 : playerBar.status.volume
                onMoved: Daemon.setVolume(Math.round(value))
            }

            IconButton {
                iconName: "picture_in_picture"
                iconSize: 18
                toolTip: qsTr("Now Playing")
                onClicked: playerBar.openNowPlaying()
            }

            IconButton {
                iconName: "queue"
                iconSize: 18
                toolTip: qsTr("Queue")
                onClicked: playerBar.queueRequested()
            }
        }
    }
}
