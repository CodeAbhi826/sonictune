// pages/NowPlayingPage.qml — full-screen now-playing overlay (Material 3).
// Opened as a bottom-edge Drawer from the floating PlayerBar. Includes
// transport, seek, speed, quality badge, a QML-only sleep timer, and a
// toggleable lyrics panel.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"

Item {
    id: nowPlayingPage

    signal queueRequested()
    signal closeRequested()

    property var status: ({})
    property var currentTrack: ({})
    property var queue: ({})
    property int positionMs: 0
    property int durationMs: 0
    property bool isPlaying: false
    property var lyricsModel: []

    property string audioQuality: "standard"
    property int currentItag: 0
    property real speedValue: 1.0
    property bool lyricsVisible: false

    property int sleepTimerSeconds: 0
    property int sleepTimerRemainingMs: 0
    property bool sleepAtTrackEnd: false

    readonly property int artSize: Math.min(320, nowPlayingPage.width * 0.42)

    readonly property var sleepOptions: [
        { key: 0, label: qsTr("Off") },
        { key: 5, label: qsTr("5 minutes") },
        { key: 15, label: qsTr("15 minutes") },
        { key: 30, label: qsTr("30 minutes") },
        { key: 45, label: qsTr("45 minutes") },
        { key: 60, label: qsTr("60 minutes") },
        { key: -1, label: qsTr("End of track") }
    ]

    readonly property var speedOptions: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    function queueTracks() {
        var q = nowPlayingPage.queue
        return (q && q.tracks) || []
    }

    Connections {
        target: Daemon
        function onTrackChanged(track) {
            nowPlayingPage.currentTrack = track || {}
            nowPlayingPage.lyricsModel = []
            if (nowPlayingPage.sleepAtTrackEnd) {
                nowPlayingPage.stopSleepTimer()
                Daemon.pause()
            }
            // Fetch lyrics for the new track
            if (track && track.title) {
                Daemon.getLyrics(
                    track.title,
                    track.artist || "",
                    track.album || "",
                    track.duration_ms || 0
                )
            }
        }
        function onPositionChanged(pos, dur) {
            nowPlayingPage.positionMs = pos
            nowPlayingPage.durationMs = dur
        }
        function onStateChanged(state) {
            nowPlayingPage.isPlaying = state === "playing"
        }
        function onStatusReceived(s) {
            nowPlayingPage.status = s || {}
            nowPlayingPage.isPlaying = s.state === "playing"
            nowPlayingPage.positionMs = s.position_ms || 0
            nowPlayingPage.durationMs = s.duration_ms || 0
            if (s.track) nowPlayingPage.currentTrack = s.track
            if (typeof s.audio_quality === "string") nowPlayingPage.audioQuality = s.audio_quality
        }
        function onQueueChanged() {
            Daemon.getStatus()
        }
        function onQueueReceived(q) {
            nowPlayingPage.queue = q || {}
        }
        function onAudioQualityChanged(q) { nowPlayingPage.audioQuality = q }
        function onCurrentAudioItagChanged(itag) { nowPlayingPage.currentItag = itag }
        function onLyricsReceived(lines) {
            nowPlayingPage.lyricsModel = lines
        }
        function onLyricsError(err) {
            toast.show(qsTr("Lyrics unavailable: %1").arg(err))
            nowPlayingPage.lyricsModel = []
        }
    }

    Component.onCompleted: {
        Daemon.getStatus()
        Daemon.getQueue()
        nowPlayingPage.audioQuality = Daemon.audioQuality()
        nowPlayingPage.currentItag = Daemon.currentAudioItag()
        nowPlayingPage.speedValue = Daemon.speed()
    }

    // --- Sleep timer (pure QML — Daemon has no setSleepTimer yet) ----------
    Timer {
        id: sleepTimer
        interval: 1000
        repeat: true
        onTriggered: {
            nowPlayingPage.sleepTimerRemainingMs = Math.max(0, nowPlayingPage.sleepTimerRemainingMs - 1000)
            if (nowPlayingPage.sleepTimerRemainingMs <= 0) {
                nowPlayingPage.stopSleepTimer()
                Daemon.pause()
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    Image {
        anchors.fill: parent
        source: nowPlayingPage.currentTrack.thumbnail_url
            ? "image://art/" + encodeURIComponent(nowPlayingPage.currentTrack.thumbnail_url)
            : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: 0.06
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.background }
            GradientStop { position: 0.85; color: Theme.background }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // --- Top bar -------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            Layout.leftMargin: Theme.space2
            Layout.rightMargin: Theme.space4
            spacing: Theme.space3

            IconButton {
                icon: "arrowBack"
                diameter: 40
                iconSize: 20
                onClicked: nowPlayingPage.closeRequested()
            }

            Item { Layout.fillWidth: true }

            Text {
                text: qsTr("Now Playing")
                color: Theme.fgSurfaceVariant
                font: Theme.fontLabelMedium
            }

            Item { Layout.fillWidth: true }

            IconButton {
                icon: "queue"
                diameter: 40
                iconSize: 20
                onClicked: nowPlayingPage.queueRequested()
            }
        }

        // --- Content -------------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // --- Tab bar: Player | Lyrics | Queue --------------------------
            TabBar {
                id: npTabs
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                z: 10

                background: Rectangle { color: "transparent" }

                TabButton {
                    text: qsTr("Player")
                    font: Theme.fontLabelLarge
                    onClicked: npStack.currentIndex = 0
                }
                TabButton {
                    text: qsTr("Lyrics")
                    font: Theme.fontLabelLarge
                    onClicked: npStack.currentIndex = 1
                }
                TabButton {
                    text: qsTr("Queue")
                    font: Theme.fontLabelLarge
                    onClicked: npStack.currentIndex = 2
                }
            }

            StackLayout {
                id: npStack
                anchors.top: npTabs.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                currentIndex: 0

                // --- Player tab -------------------------------------------
                Flickable {
                    id: playerScroll
                    clip: true
                    contentWidth: width
                    contentHeight: playerColumn.implicitHeight + Theme.space8

                    ColumnLayout {
                        id: playerColumn
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(520, parent.width - Theme.space8)
                        spacing: Theme.space4

                    // Artwork
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: nowPlayingPage.artSize
                        Layout.preferredHeight: nowPlayingPage.artSize
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
                            color: Theme.fgSurfaceVariant
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: nowPlayingPage.currentTrack.title || qsTr("Nothing playing")
                            color: Theme.fgSurface
                            font: Theme.fontHeadlineMedium
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            Layout.fillWidth: true
                            text: nowPlayingPage.currentTrack.artist || ""
                            color: Theme.fgSurfaceVariant
                            font: Theme.fontBodyLarge
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    // Seek
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
                            text: Theme.formatDuration(nowPlayingPage.positionMs)
                            color: Theme.fgSurfaceVariant
                            font: Theme.fontMono
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "-" + Theme.formatDuration(Math.max(0, nowPlayingPage.durationMs - nowPlayingPage.positionMs))
                            color: Theme.fgSurfaceVariant
                            font: Theme.fontMono
                        }
                    }

                    // Transport
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Theme.space4

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

                    // Speed + quality + sleep + lyrics
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Theme.space4

                        STButton {
                            id: speedButton
                            text: nowPlayingPage.speedValue.toFixed(2) + "x"
                            iconName: "speed"
                            variant: "tonal"
                            onClicked: speedPopup.open()
                        }

                        Text {
                            text: nowPlayingPage.qualityText()
                            color: Theme.fgSurfaceVariant
                            font: Theme.fontLabelMedium
                        }

                        IconButton {
                            icon: "timer"
                            diameter: 40
                            iconSize: 18
                            highlighted: nowPlayingPage.sleepTimerSeconds > 0 || nowPlayingPage.sleepAtTrackEnd
                            onClicked: sleepPopup.open()
                        }

                        IconButton {
                            icon: "lyrics"
                            diameter: 40
                            iconSize: 18
                            highlighted: npStack.currentIndex === 1
                            onClicked: npStack.currentIndex = 1
                        }
                    }

                    // Sleep timer remaining label
                    Text {
                        id: sleepTimerRemaining
                        Layout.alignment: Qt.AlignHCenter
                        visible: nowPlayingPage.sleepTimerSeconds > 0 || nowPlayingPage.sleepAtTrackEnd
                        text: nowPlayingPage.sleepAtTrackEnd
                            ? qsTr("Sleep at end of track")
                            : qsTr("Sleep in %1").arg(Theme.formatDuration(nowPlayingPage.sleepTimerRemainingMs))
                        color: Theme.fgSurfaceVariant
                        font: Theme.fontLabelMedium
                    }
                }
            }

            // --- Lyrics tab ------------------------------------------------
            SyncedLyricsView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: Theme.space4
                currentTrackTitle: nowPlayingPage.currentTrack.title || ""
                currentTrackArtist: nowPlayingPage.currentTrack.artist || ""
                currentTrackAlbum: nowPlayingPage.currentTrack.album || ""
                currentTrackDurationMs: nowPlayingPage.durationMs
                currentPositionMs: nowPlayingPage.positionMs
                model: nowPlayingPage.lyricsModel
            }

            // --- Queue tab ---------------------------------------------------
            Item {
                id: queueTab
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                property var queue: nowPlayingPage.queue
                property string currentVideoId: nowPlayingPage.currentTrack.video_id
                    || nowPlayingPage.currentTrack.videoId || ""

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.space4
                    spacing: Theme.space3

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("%n track(s)", "", (queueTracks().length))
                            color: Theme.fgSurfaceVariant
                            font: Theme.fontBodySmall
                        }
                        Item { Layout.fillWidth: true }
                        IconButton {
                            iconName: "sync"
                            iconSize: 16
                            toolTip: qsTr("Refresh")
                            onClicked: Daemon.getQueue()
                        }
                    }

                    ListView {
                        id: queueList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: Theme.space1
                        boundsBehavior: Flickable.StopAtBounds
                        cacheBuffer: Theme.listCacheBuffer

                        model: queueTracks()

                        delegate: Item {
                            id: queueRow
                            required property var modelData
                            required property int index

                            width: queueList.width
                            height: 56

                            readonly property bool isCurrent:
                                (modelData.video_id || modelData.videoId || "") === queueTab.currentVideoId

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusSm
                                color: queueRow.isCurrent
                                    ? Theme.primaryContainer
                                    : (rowMa.containsMouse ? Theme.surfaceContainerHigh : "transparent")
                                Behavior on color {
                                    enabled: !Theme.reducedMotion
                                    ColorAnimation { duration: Theme.durFast }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.space3
                                    anchors.rightMargin: Theme.space2
                                    spacing: Theme.space3

                                    Text {
                                        Layout.preferredWidth: 24
                                        text: queueRow.isCurrent ? "" : (queueRow.index + 1)
                                        color: Theme.fgSurfaceVariant
                                        font: Theme.fontMono
                                        horizontalAlignment: Text.AlignRight
                                    }

                                    Icon {
                                        visible: queueRow.isCurrent
                                        Layout.preferredWidth: 24
                                        name: "note"
                                        size: 13
                                        color: Theme.primary
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.title || ""
                                            color: queueRow.isCurrent ? Theme.fgPrimaryContainer : Theme.fgSurface
                                            font: Theme.fontBodyMedium
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.artist || ""
                                            color: Theme.fgSurfaceVariant
                                            font: Theme.fontBodySmall
                                            elide: Text.ElideRight
                                        }
                                    }

                                    IconButton {
                                        iconName: "close"
                                        iconSize: 14
                                        toolTip: qsTr("Remove from queue")
                                        visible: rowMa.containsMouse || queueRow.isCurrent
                                        onClicked: Daemon.removeFromQueue(queueRow.index)
                                    }
                                }

                                MouseArea {
                                    id: rowMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: queueList.count === 0
                            spacing: Theme.space2
                            Icon {
                                Layout.alignment: Qt.AlignHCenter
                                name: "queue_music"
                                size: 26
                                color: Theme.fgSurfaceVariant
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("Queue is empty")
                                color: Theme.fgSurfaceVariant
                                font: Theme.fontBodyMedium
                            }
                        }
                    }
                }
            }
        }

        }
    }

    // --- Speed menu ----------------------------------------------------------
    Popup {
        id: speedPopup
        anchors.centerIn: parent
        width: 220
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.surfaceContainerHigh
            radius: Theme.radiusMd
            border.color: Theme.outline
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: Theme.space2

            Text {
                text: qsTr("Playback speed")
                color: Theme.fgSurface
                font: Theme.fontTitleMedium
            }

            Repeater {
                model: nowPlayingPage.speedOptions
                delegate: STButton {
                    required property var modelData
                    text: modelData.toFixed(2) + "x"
                    variant: nowPlayingPage.speedValue === modelData ? "filled" : "tonal"
                    Layout.fillWidth: true
                    onClicked: {
                        nowPlayingPage.speedValue = modelData
                        Daemon.setSpeed(modelData)
                        speedPopup.close()
                    }
                }
            }
        }
    }

    // --- Sleep timer menu -----------------------------------------------------
    Popup {
        id: sleepPopup
        anchors.centerIn: parent
        width: 220
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.surfaceContainerHigh
            radius: Theme.radiusMd
            border.color: Theme.outline
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: Theme.space2

            Text {
                text: qsTr("Sleep timer")
                color: Theme.fgSurface
                font: Theme.fontTitleMedium
            }

            Repeater {
                model: nowPlayingPage.sleepOptions
                delegate: STButton {
                    required property var modelData
                    text: modelData.label
                    variant: "tonal"
                    Layout.fillWidth: true
                    onClicked: {
                        var key = modelData.key
                        if (key === 0) {
                            nowPlayingPage.stopSleepTimer()
                        } else if (key === -1) {
                            nowPlayingPage.setSleepAtTrackEnd()
                        } else {
                            nowPlayingPage.setSleepTimer(key)
                        }
                        sleepPopup.close()
                    }
                }
            }
        }
    }

    ErrorToast { id: toast }

    function setSleepTimer(minutes) {
        nowPlayingPage.sleepAtTrackEnd = false
        nowPlayingPage.sleepTimerSeconds = minutes * 60
        nowPlayingPage.sleepTimerRemainingMs = nowPlayingPage.sleepTimerSeconds * 1000
        sleepTimer.start()
    }

    function setSleepAtTrackEnd() {
        sleepTimer.stop()
        nowPlayingPage.sleepAtTrackEnd = true
        nowPlayingPage.sleepTimerSeconds = 0
        nowPlayingPage.sleepTimerRemainingMs = 0
    }

    function stopSleepTimer() {
        sleepTimer.stop()
        nowPlayingPage.sleepTimerSeconds = 0
        nowPlayingPage.sleepTimerRemainingMs = 0
        nowPlayingPage.sleepAtTrackEnd = false
    }

    function qualityText() {
        var q = nowPlayingPage.audioQuality || "standard"
        return q.toUpperCase() + " · " + nowPlayingPage.codecLabel()
    }

    function codecLabel() {
        if (nowPlayingPage.currentItag === 141) return "256kbps AAC (Premium)"
        if (nowPlayingPage.currentItag === 774) return "256kbps Opus"
        if (nowPlayingPage.currentItag === 251) return "128kbps Opus"
        return "Auto"
    }

    function formatTime(ms) {
        return Theme.formatDuration(ms)
    }
}
