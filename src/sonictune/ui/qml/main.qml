// main.qml — SonicTune main window (Material 3 Dark).
// Desktop NavigationRail + StackView + persistent NowPlayingBar.

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window
import "theme"
import "pages"
import "components"
import "router"

ApplicationWindow {
    id: window
    visible: true
    width: 1320
    height: 840
    minimumWidth: 760
    minimumHeight: 600
    title: qsTr("SonicTune")
    color: Theme.background

    property real globalScale: Math.max(1.0, Screen.pixelDensity / 120.0)
    function dp(size) { return Math.round(size * globalScale) }

    Material.theme: Material.Dark
    Material.accent: Theme.primary
    Material.primary: Theme.primary
    Material.foreground: Theme.onSurface
    Material.background: Theme.background

    property int cachedVolume: 80
    property bool daemonConnected: Daemon.isConnected()

    signal miniPlayerToggleRequested()

    Component.onCompleted: Router.stackView = contentStack

    Connections {
        target: Daemon
        function onConnectionChanged(connected) { window.daemonConnected = connected }
        function onError(err) { appToast.show(err) }
        function onErrorOccurred(err) { appToast.show(err) }
    }

    // --- Connection banner --------------------------------------------------
    Rectangle {
        id: connectionBanner
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: window.daemonConnected ? 0 : 40
        color: Theme.errorContainer
        visible: height > 0
        clip: true
        Behavior on height {
            enabled: !Theme.reducedMotion
            NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic }
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: Theme.space2
            Icon { name: "warning"; size: 16; color: Theme.onErrorContainer }
            Text {
                color: Theme.onErrorContainer
                text: qsTr("Can't reach the daemon — retrying… start it with ./scripts/run-daemon.sh")
                font: Theme.fontBodySmall
            }
        }
    }

    // --- Main Layout: NavRail + ContentStack + NowPlayingBar ---------------
    RowLayout {
        anchors.top: connectionBanner.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 0

        // Left Navigation Rail (Spotube/Harmonoid style)
        NavRail {
            id: navRail
            Layout.preferredWidth: 88
            Layout.fillHeight: true
            stackView: contentStack
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Theme.outline
        }

        // Main Content Area (StackView for all pages)
        StackView {
            id: contentStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.bottomMargin: 80 // Space for NowPlayingBar

            initialItem: "qrc:/qml/pages/HomePage.qml"

            pushEnter: Transition {
                enabled: !Theme.reducedMotion
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durNormal }
                    NumberAnimation { property: "x"; from: 40; to: 0; duration: Theme.durNormal; easing.type: Easing.OutCubic }
                }
            }
            pushExit: Transition {
                enabled: !Theme.reducedMotion
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durFast }
            }
            popEnter: Transition {
                enabled: !Theme.reducedMotion
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durFast }
            }
            popExit: Transition {
                enabled: !Theme.reducedMotion
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durNormal }
                    NumberAnimation { property: "x"; from: 0; to: -40; duration: Theme.durNormal; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    // --- Persistent Bottom Now Playing Bar ---------------------------------
    NowPlayingBar {
        id: nowPlayingBar
        anchors.bottom: parent.bottom
        width: parent.width
        height: 80
        z: 100
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
        z: 200

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
        z: 200
    }

    ErrorToast {
        id: appToast
        anchors.fill: parent
        z: 300
    }

    // --- Shortcuts (9 total) ------------------------------------------------
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
        sequence: "Ctrl+Up"
        onActivated: Daemon.setVolume(Math.min(100, window.cachedVolume + 5))
    }
    Shortcut {
        sequence: "Ctrl+Down"
        onActivated: Daemon.setVolume(Math.max(0, window.cachedVolume - 5))
    }
    Shortcut {
        sequence: "Ctrl+L"
        onActivated: {
            contentStack.currentIndex = 1 // Search
            searchPage.focusSearch()
        }
    }
    Shortcut {
        sequence: "Ctrl+Q"
        onActivated: queueDrawer.open()
    }
    Shortcut {
        sequence: "Ctrl+M"
        onActivated: window.miniPlayerToggleRequested()
    }
    Shortcut {
        sequence: "Ctrl+F"
        onActivated: contentStack.currentIndex = 1 // Search
    }

    Connections {
        target: Daemon
        function onStatusReceived(s) {
            window.cachedVolume = s.volume || window.cachedVolume
            if (s.track && s.track.title) {
                window.title = qsTr("%1 · %2 — SonicTune").arg(s.track.title).arg(s.track.artist || "")
            } else {
                window.title = qsTr("SonicTune")
            }
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
