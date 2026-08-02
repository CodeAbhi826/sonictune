import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window
import "theme"
import "pages"
import "components"

ApplicationWindow {
    id: window
    visible: true
    width: 1320
    height: 840
    minimumWidth: 760
    minimumHeight: 600
    title: qsTr("SonicTune")
    color: Theme.background

    Material.theme: Theme.materialTheme
    Material.accent: Theme.primary
    Material.primary: Theme.primary
    Material.foreground: Theme.onSurface
    Material.background: Theme.background

    property int cachedVolume: 80
    property bool daemonConnected: Daemon.isConnected()

    Connections {
        target: Daemon
        function onConnectionChanged(connected) { daemonConnected = connected }
    }

    // --- Connection banner --------------------------------------------------
    Rectangle {
        id: connectionBanner
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: daemonConnected ? 0 : 40
        color: Theme.error
        visible: height > 0
        clip: true

        Behavior on height { NumberAnimation { duration: Theme.durationBase; easing.type: Theme.easingStandard } }

        RowLayout {
            anchors.centerIn: parent
            spacing: Theme.spacingSm
            Icon { name: "warning"; size: 16; color: Theme.onError }
            Text {
                color: Theme.onError
                text: qsTr("Can't reach the daemon — retrying… start it with ./scripts/run-daemon.sh")
                font: Theme.fontBodySmall
            }
        }
    }

    RowLayout {
        anchors.top: connectionBanner.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 0

        NavRail {
            id: navRail
            Layout.fillHeight: true
            Layout.preferredWidth: 88
            currentIndex: pageStack.currentIndex
            onNavigate: function(pageName) {
                pageStack.switchTo(pageName)
            }
        }

        Rectangle {
            Layout.fillWidth: false
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: Theme.outline
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            StackLayout {
                id: pageStack
                Layout.fillWidth: true
                Layout.fillHeight: true

                function switchTo(name) {
                    currentIndex = {
                        "home": 0,
                        "search": 1,
                        "library": 2,
                        "stats": 3,
                        "nowplaying": 4,
                        "settings": 5
                    }[name] || 0
                }

                HomePage { id: homePage }
                SearchPage { id: searchPage }
                LibraryPage {
                    id: libraryPage
                    onNavigateRequested: function(name) { pageStack.switchTo(name) }
                }
                StatsPage { id: statsPage }
                NowPlayingPage {
                    id: nowPlayingPage
                    onQueueRequested: queueDrawer.open()
                }
                SettingsPage { id: settingsPage }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.outline
            }

            PlayerBar {
                id: playerBar
                Layout.fillWidth: true
                Layout.preferredHeight: 88
                onQueueRequested: queueDrawer.open()
                onOpenNowPlaying: pageStack.switchTo("nowplaying")
            }
        }
    }

    QueueDrawer {
        id: queueDrawer
    }

    Shortcut {
        sequence: "Space"
        onActivated: Daemon.playPause()
    }
    Shortcut {
        sequence: "Ctrl+Right"
        onActivated: Daemon.next()
    }
    Shortcut {
        sequence: "Ctrl+Left"
        onActivated: Daemon.previous()
    }
    Shortcut {
        sequence: "Ctrl+F"
        onActivated: pageStack.switchTo("search")
    }
    Shortcut {
        sequence: "Ctrl+Up"
        onActivated: Daemon.setVolume(Math.min(100, window.cachedVolume + 5))
    }
    Shortcut {
        sequence: "Ctrl+Down"
        onActivated: Daemon.setVolume(Math.max(0, window.cachedVolume - 5))
    }
    Shortcut {
        sequence: "Ctrl+Q"
        onActivated: queueDrawer.open()
    }

    Connections {
        target: Daemon
        function onStatusReceived(s) {
            window.cachedVolume = s.volume || window.cachedVolume
        }
        function onTrackChanged(track) {
            if (track && track.title) {
                window.title = qsTr("%1 · %2 — SonicTune").arg(track.title).arg(track.artist || "")
            } else {
                window.title = qsTr("SonicTune")
            }
        }
    }
}
