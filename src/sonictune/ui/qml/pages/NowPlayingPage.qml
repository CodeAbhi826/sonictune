// pages/NowPlayingPage.qml — full-screen now-playing overlay.
// Opened as a bottom-edge Drawer from the floating PlayerBar (NOT a rail
// tab). Background is the album art at 8% opacity under a vertical
// gradient — no GaussianBlur.

import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"

Item {
    id: nowPlayingPage

    signal queueRequested()
    signal closeRequested()

    property var status: ({})
    property var currentTrack: ({})
    property int positionMs: 0
    property int durationMs: 0
    property bool isPlaying: false

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

    // --- Background: art at 8% opacity + gradient ------------------------
    Image {
        anchors.fill: parent
        source: nowPlayingPage.currentTrack.thumbnail_url
            ? "image://art/" + encodeURIComponent(nowPlayingPage.currentTrack.thumbnail_url)
            : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: 0.08
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.background }
            GradientStop { position: 0.7; color: Theme.background }
        }
    }

    // --- Top bar -----------------------------------------------------------
    RowLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingSm

        IconButton {
            icon: "arrowBack"
            diameter: 40
            iconSize: 20
            onClicked: nowPlayingPage.closeRequested()
        }

        Item { Layout.fillWidth: true }

        IconButton {
            icon: "moreVert"
            diameter: 40
            iconSize: 20
        }
    }

    // --- Content -----------------------------------------------------------
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(460, parent.width - Theme.spacingXl * 2)
        spacing: Theme.spacingLg

        Item { Layout.preferredHeight: Theme.spacingLg }

        Rectangle {
            Layout.preferredWidth: Math.min(360, parent.width * 0.5)
            Layout.preferredHeight: Math.min(360, parent.width * 0.5)
            Layout.alignment: Qt.AlignHCenter
            radius: Theme.radiusXl
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
                name: "album"
                size: 48
                color: Theme.onSurfaceVariant
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                Layout.fillWidth: true
                text: nowPlayingPage.currentTrack.title || qsTr("Nothing playing")
                color: Theme.onSurface
                font: Theme.fontTitleLarge
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                Layout.fillWidth: true
                text: nowPlayingPage.currentTrack.artist || ""
                color: Theme.onSurfaceVariant
                font: Theme.fontBodyLarge
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // --- Seek bar --------------------------------------------------------
        STSlider {
            Layout.fillWidth: true
            from: 0
            to: Math.max(1, nowPlayingPage.durationMs)
            value: Math.min(nowPlayingPage.positionMs, nowPlayingPage.durationMs)
            onMoved: Daemon.seek(value)
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: nowPlayingPage.formatTime(nowPlayingPage.positionMs)
                color: Theme.onSurfaceMuted
                font: Theme.fontMono
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "-" + nowPlayingPage.formatTime(nowPlayingPage.durationMs - nowPlayingPage.positionMs)
                color: Theme.onSurfaceMuted
                font: Theme.fontMono
            }
        }

        // --- Transport ---------------------------------------------------------
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.spacingLg

            IconButton {
                icon: "shuffle"
                diameter: 40
                iconSize: 18
                highlighted: nowPlayingPage.status.shuffle === true
                onClicked: Daemon.setShuffle(!nowPlayingPage.status.shuffle)
            }
            IconButton {
                icon: "previous"
                diameter: 48
                iconSize: 22
                onClicked: Daemon.previous()
            }
            IconButton {
                icon: nowPlayingPage.isPlaying ? "pause" : "play"
                diameter: 64
                iconSize: 28
                prominent: true
                onClicked: Daemon.playPause()
            }
            IconButton {
                icon: "next"
                diameter: 48
                iconSize: 22
                onClicked: Daemon.next()
            }
            IconButton {
                property string mode: nowPlayingPage.status.repeat || "off"
                icon: mode === "one" ? "repeatOne" : "repeat"
                diameter: 40
                iconSize: 18
                highlighted: mode !== "off"
                onClicked: {
                    var next = mode === "off" ? "all" : mode === "all" ? "one" : "off"
                    Daemon.setRepeat(next)
                }
            }
        }

        // --- Bottom actions -----------------------------------------------------
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.spacingXl
            Layout.topMargin: Theme.spacingSm

            IconButton { icon: "lyrics"; diameter: 40; iconSize: 18 }
            IconButton {
                icon: "queue"
                diameter: 40
                iconSize: 18
                onClicked: nowPlayingPage.queueRequested()
            }
            IconButton { icon: "timer"; diameter: 40; iconSize: 18 }
            IconButton { icon: "speaker"; diameter: 40; iconSize: 18 }
        }

        Item { Layout.preferredHeight: Theme.spacingXl }
    }

    function formatTime(ms) {
        if (!ms || ms <= 0) return "0:00"
        var s = Math.floor(ms / 1000)
        var m = Math.floor(s / 60)
        s = s % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }
}
