// src/sonictune/ui/qml/MiniPlayer.qml — compact floating mini player
// (320x80, frameless QQuickView). Loaded with the Daemon context property
// already available.

import QtQuick
import QtQuick.Layouts
import "theme"
import "components"

Rectangle {
    id: root
    width: 320
    height: 80
    radius: Theme.radiusLg
    color: Theme.surfaceContainerHighest
    clip: true

    signal closeRequested()

    property var currentTrack: ({})
    property int positionMs: 0
    property int durationMs: 0
    property bool isPlaying: false

    Connections {
        target: Daemon
        function onTrackChanged(track) { root.currentTrack = track || {} }
        function onStateChanged(state) { root.isPlaying = state === "playing" }
        function onPositionChanged(pos, dur) {
            root.positionMs = pos
            root.durationMs = dur
        }
        function onStatusReceived(s) {
            root.currentTrack = s.track || {}
            root.isPlaying = s.state === "playing"
            root.positionMs = s.position_ms || 0
            root.durationMs = s.duration_ms || 0
        }
    }

    Component.onCompleted: Daemon.getStatus()

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.space2
        spacing: Theme.space2

        // Artwork
        Rectangle {
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            radius: Theme.radiusSm
            color: Theme.surfaceContainer
            clip: true

            Image {
                anchors.fill: parent
                source: root.currentTrack.thumbnail_url
                    ? "image://art/" + encodeURIComponent(root.currentTrack.thumbnail_url)
                    : (root.currentTrack.videoId ? "image://art/" + root.currentTrack.videoId : "")
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Icon {
                anchors.centerIn: parent
                visible: !root.currentTrack.thumbnail_url
                name: "note"
                size: 20
                color: Theme.fgSurfaceVariant
            }
        }

        // Track info
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.currentTrack.title || qsTr("Nothing playing")
                color: Theme.fgSurface
                font: Theme.fontBodyMedium
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Text {
                Layout.fillWidth: true
                text: root.currentTrack.artist || ""
                color: Theme.fgSurfaceVariant
                font: Theme.fontBodySmall
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // Transport
        IconButton {
            icon: root.isPlaying ? "pause" : "play"
            diameter: 40
            iconSize: 18
            prominent: true
            onClicked: Daemon.playPause()
        }
        IconButton {
            icon: "next"
            diameter: 32
            iconSize: 15
            onClicked: Daemon.next()
        }
        IconButton {
            icon: "close"
            diameter: 26
            iconSize: 12
            onClicked: root.closeRequested()
        }
    }

    // 2px progress bar at the bottom
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: parent.width * (root.durationMs > 0 ? Math.min(1, root.positionMs / root.durationMs) : 0)
        height: 2
        color: Theme.playerProgress
        Behavior on width { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.durFast } }
    }
}
