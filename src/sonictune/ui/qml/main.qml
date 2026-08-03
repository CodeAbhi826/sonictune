import QtQuick
import QtQuick.Controls
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
        function onConnectionChanged(connected) { window.daemonConnected = connected }
    }

    // --- Connection banner --------------------------------------------------
    Rectangle {
        id: connectionBanner
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: window.daemonConnected ? 0 : 40
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

        Item {
            id: contentArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Padding so the floating PlayerBar doesn't cover content.
            StackLayout {
                id: pageStack
                anchors.fill: parent
                anchors.bottomMargin: 104

                function switchTo(name) {
                    currentIndex = {
                        "home": 0,
                        "search": 1,
                        "library": 2,
                        "stats": 3,
                        "settings": 4
                    }[name] || 0
                }

                HomePage { id: homePage }
                SearchPage { id: searchPage }
                LibraryPage {
                    id: libraryPage
                    onNavigateRequested: function(name) { pageStack.switchTo(name) }
                }
                StatsPage { id: statsPage }
                SettingsPage { id: settingsPage }
            }
        }
    }

    // --- Floating PlayerBar ------------------------------------------------
    PlayerBar {
        id: playerBar
        anchors.left: parent.left
        anchors.leftMargin: navRail.width + Theme.spacingMd
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingMd
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spacingMd
        height: 72
        z: 10
        onQueueRequested: queueDrawer.open()
        onOpenNowPlaying: nowPlayingDrawer.open()
    }

    // --- Now Playing overlay (Drawer from the bottom edge) ------------------
    Drawer {
        id: nowPlayingDrawer
        edge: Qt.BottomEdge
        width: parent.width
        height: parent.height
        interactive: false
        modal: true
        dragMargin: 0

        background: Rectangle {
            color: Theme.background
        }

        NowPlayingPage {
            anchors.fill: parent
            onQueueRequested: queueDrawer.open()
            onCloseRequested: nowPlayingDrawer.close()
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
    Shortcut {
        sequence: "Escape"
        onActivated: nowPlayingDrawer.close()
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
