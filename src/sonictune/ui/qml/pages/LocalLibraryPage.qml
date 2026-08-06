// pages/LocalLibraryPage.qml — Local audio library browser (Material 3 Dark).
// Shows tracks, albums, and artists from local files. Supports playback
// and merging with the online library.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../theme"
import "../components"

Page {
    id: localLibraryPage
    title: qsTr("Local Library")

    property var localTracksModel: []
    property bool isScanning: false
    property string scanPath: ""
    property int scanProgress: 0
    property int scanTotal: 0
    property int scanProcessed: 0

    Connections {
        target: Daemon
        function onLocalTracksReceived(tracks) {
            localLibraryPage.localTracksModel = tracks
            localLibraryPage.isScanning = false
        }
        function onLocalTracksError(error) {
            appToast.show(qsTr("Scan failed: %1").arg(error))
            localLibraryPage.isScanning = false
        }
        function onLocalScanProgress(path, processed, total) {
            localLibraryPage.scanPath = path
            localLibraryPage.scanProcessed = processed
            localLibraryPage.scanTotal = total
            localLibraryPage.isScanning = true
        }
        function onLocalScanCompleted() {
            localLibraryPage.isScanning = false
        }
    }

    function handleScanRequested(path) {
        localLibraryPage.isScanning = true
        Daemon.scanLocalLibrary(path)
    }

    function handlePlayLocalTrack(trackId) {
        Daemon.playLocalTrack(trackId)
    }

    function handleAddLocalTrackToQueue(trackId) {
        Daemon.addLocalTrackToQueue(trackId, false)
    }

    // --- Header --------------------------------------------------------------
    header: ColumnLayout {
        width: parent.width
        spacing: 0

        // Title row
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.space4
            Layout.rightMargin: Theme.space4
            Layout.topMargin: Theme.space4
            Layout.bottomMargin: Theme.space2
            spacing: Theme.space4

            Text {
                text: qsTr("Local Library")
                color: Theme.fgSurface
                font: Theme.fontHeadlineSmall
                Layout.fillWidth: true
            }

            IconButton {
                iconName: "refresh"
                iconSize: 20
                toolTip: qsTr("Rescan library")
                onClicked: scanDialog.open()
            }
        }

        // Tabs
        TabBar {
            id: libraryTabs
            Layout.fillWidth: true
            currentIndex: 0
            background: Rectangle {
                color: Theme.surfaceContainer
                implicitHeight: 48
            }

            TabButton {
                text: qsTr("Tracks")
            }
            TabButton {
                text: qsTr("Albums")
            }
            TabButton {
                text: qsTr("Artists")
            }
            TabButton {
                text: qsTr("Folders")
            }
        }
    }

    // --- Content -------------------------------------------------------------
    StackLayout {
        id: contentStack
        anchors.fill: parent
        currentIndex: libraryTabs.currentIndex

        // Tracks tab
        TrackList {
            id: tracksList
                tracks: localLibraryPage.localTracksModel
            currentTrackId: ""  // Will be set by Daemon when playing
            onPlayLocalTrack: localLibraryPage.handlePlayLocalTrack(trackId)
            onAddLocalTrackToQueue: localLibraryPage.handleAddLocalTrackToQueue(trackId)
            emptyMessage: qsTr("No local tracks found")
            emptyAction: qsTr("Scan Music Folder")
            onEmptyActionClicked: scanDialog.open()
        }

        // Albums tab (placeholder)
        Item {
            Label {
                anchors.centerIn: parent
                text: qsTr("Albums view coming soon")
                color: Theme.fgSurfaceVariant
                font: Theme.fontBodyLarge
            }
        }

        // Artists tab (placeholder)
        Item {
            Label {
                anchors.centerIn: parent
                text: qsTr("Artists view coming soon")
                color: Theme.fgSurfaceVariant
                font: Theme.fontBodyLarge
            }
        }

        // Folders tab (placeholder)
        Item {
            Label {
                anchors.centerIn: parent
                text: qsTr("Folders view coming soon")
                color: Theme.fgSurfaceVariant
                font: Theme.fontBodyLarge
            }
        }
    }

    // --- Scan progress overlay -----------------------------------------------
    Rectangle {
        id: scanOverlay
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.7)
        visible: localLibraryPage.isScanning
        z: 100

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Theme.space4

            ProgressBar {
                Layout.fillWidth: true
                from: 0
                to: localLibraryPage.scanTotal
                value: localLibraryPage.scanProcessed
                indeterminate: localLibraryPage.scanTotal === 0
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.space2

                Text {
                    text: qsTr("Scanning: %1").arg(localLibraryPage.scanPath)
                    color: Theme.fgSurface
                    font: Theme.fontBodyMedium
                }

                Text {
                    text: qsTr("%1 / %2").arg(localLibraryPage.scanProcessed).arg(localLibraryPage.scanTotal)
                    color: Theme.fgSurfaceVariant
                    font: Theme.fontBodyMedium
                }
            }

STButton {
    text: qsTr("Cancel")
    variant: "tonal"
    onClicked: localLibraryPage.isScanning = false
}
        }
    }

    // --- Scan path dialog ----------------------------------------------------
    Dialog {
        id: scanDialog
        title: qsTr("Scan Local Library")
        standardButtons: Dialog.Ok | Dialog.Cancel

        ColumnLayout {
            spacing: Theme.space4
            width: 400

            Text {
                text: qsTr("Select a folder to scan for audio files:")
                color: Theme.fgSurface
                font: Theme.fontBodyLarge
                Layout.fillWidth: true
            }

            TextField {
                id: scanPathField
                text: localLibraryPage.scanPath || ""
                placeholderText: qsTr("Enter path or use file dialog")
                Layout.fillWidth: true
                onAccepted: scanDialog.accept()
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space4

               STButton {
                    text: qsTr("Browse…")
                    variant: "outlined"
                    onClicked: fileDialog.open()
                }

                Item { Layout.fillWidth: true }

               STButton {
                    text: qsTr("Scan")
                    variant: "filled"
                    onClicked: scanDialog.accept()
                }
            }
        }

        onAccepted: {
            if (scanPathField.text) {
                localLibraryPage.scanPath = scanPathField.text
                localLibraryPage.scanRequested(scanPathField.text)
            }
        }
    }

    FileDialog {
        id: fileDialog
        title: qsTr("Select Music Folder")
        folder: shortcuts.home
        selectFolder: true
        onAccepted: scanPathField.text = fileDialog.fileUrl.toString().replace("file://", "")
    }

    // --- Empty state ---------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        visible: !localLibraryPage.isScanning && localLibraryPage.localTracksModel.length === 0
        color: Qt.rgba(0, 0, 0, 0)

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Theme.space4

            Icon {
                name: "musicNote"
                size: 48
                color: Theme.fgSurfaceVariant
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: qsTr("No local tracks found")
                color: Theme.fgSurface
                font: Theme.fontTitleLarge
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: qsTr("Scan your music folders to add local tracks to your library")
                color: Theme.fgSurfaceVariant
                font: Theme.fontBodyMedium
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                width: 300
            }

           STButton {
                text: qsTr("Scan Music Folder")
                variant: "filled"
                onClicked: scanDialog.open()
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}