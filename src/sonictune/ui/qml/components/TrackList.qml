// components/TrackList.qml — numbered track list with play/add-to-queue.
//
// Expects a `tracks` model: list of { video_id, title, artist, album,
// duration_ms, thumbnail_url }.
//
// Numbered indices render in the mono font; hovering swaps the number for
// a play glyph. The active (currently playing) row gets a primaryContainer
// background with a small equalizer glyph in Theme.primary. Renders
// cleanly with an empty model (shows the empty state instead).
//
// Note: no `pragma ComponentBehavior: Bound` — the delegate intentionally
// references outer IDs (`root.*`, `list.width`), and qmllint segfaults on
// that combination.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import theme 1.0

Rectangle {
    id: root
    color: "transparent"
    implicitHeight: list.contentHeight

    property var tracks: []
    property string currentTrackId: ""
    property bool showEmptyState: true
    property string emptyMessage: qsTr("Nothing here yet")
    property string emptyIcon: "note"
    property string emptyAction: ""

    readonly property bool empty: !root.tracks || root.tracks.length === 0
    readonly property bool hasLocalTracks: root.tracks.some(track => track.is_local)

    signal playTrack(string trackId)
    signal addToQueue(string trackId)
    signal playLocalTrack(string trackId)
    signal addLocalTrackToQueue(string trackId)
    signal emptyActionClicked()

ListView {
    id: list
    anchors.fill: parent
    clip: true
    model: root.tracks
    spacing: 2
    boundsBehavior: Flickable.StopAtBounds
    cacheBuffer: 1200

    delegate: Rectangle {
            id: row
            required property var modelData
            required property int index

            width: list.width
            height: 56
            readonly property bool isCurrent: {
                if (root.hasLocalTracks) {
                    return row.modelData.id === root.currentTrackId
                } else {
                    return row.modelData.video_id === root.currentTrackId
                }
            }
            readonly property string trackId: root.hasLocalTracks ? row.modelData.id : row.modelData.video_id
            readonly property string trackThumbnail: root.hasLocalTracks ? "" : row.modelData.thumbnail_url
            readonly property string trackTitle: row.modelData.title || qsTr("Unknown title")
            readonly property string trackArtist: row.modelData.artist || qsTr("Unknown artist")
            readonly property string trackAlbum: row.modelData.album || ""
            readonly property int trackDuration: row.modelData.duration_ms || 0
            radius: Theme.radiusMd
            color: row.isCurrent
                ? Theme.primaryContainer
                : (mouseArea.containsMouse ? Theme.surfaceContainer : "transparent")

            Behavior on color {
                enabled: !Theme.reducedMotion
                ColorAnimation { duration: Theme.durFast }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space4
                anchors.rightMargin: Theme.space4
                spacing: Theme.space2

                Item {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 40

                    Text {
                        anchors.centerIn: parent
                        visible: !row.isCurrent && !mouseArea.containsMouse
                        text: (row.index + 1) + "."
                        color: Theme.fgSurfaceVariant
                        font: Theme.fontMono
                    }

                    Icon {
                        anchors.centerIn: parent
                        visible: mouseArea.containsMouse && !row.isCurrent
                        name: "play"
                        size: 16
                        color: Theme.fgSurface
                    }

                    Icon {
                        anchors.centerIn: parent
                        visible: row.isCurrent
                        name: "equalizer"
                        size: 16
                        color: Theme.primary
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: Theme.radiusSm
                    color: Theme.surfaceContainerHigh
                    clip: true

                    Image {
                        anchors.fill: parent
                        cache: false
                        source: row.trackThumbnail
                            ? "image://art/" + encodeURIComponent(row.trackThumbnail)
                            : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    Icon {
                        anchors.centerIn: parent
                        visible: !row.trackThumbnail
                        name: "note"
                        size: 16
                        color: Theme.fgSurfaceVariant
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: row.trackTitle
                        color: row.isCurrent ? Theme.fgPrimaryContainer : Theme.fgSurface
                        font: Theme.fontBodyLarge
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: row.trackArtist + (row.trackAlbum ? "  ·  " + row.trackAlbum : "")
                        color: row.isCurrent ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
                        font: Theme.fontBodySmall
                        elide: Text.ElideRight
                    }
                }

                Text {
                    text: root.formatTime(row.trackDuration)
                    color: row.isCurrent ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
                    font: Theme.fontMono
                    Layout.preferredWidth: 44
                    horizontalAlignment: Text.AlignRight
                }

                Item {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    visible: mouseArea.containsMouse

                    Icon { anchors.centerIn: parent; name: "add"; size: 16; color: Theme.fgSurfaceVariant }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.hasLocalTracks
                            ? root.addLocalTrackToQueue(row.trackId)
                            : root.addToQueue(row.trackId)
                    }
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onWheel: (wheel) => { wheel.accepted = false }
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.LeftButton) {
                        root.hasLocalTracks
                            ? root.playLocalTrack(row.trackId)
                            : root.playTrack(row.trackId)
                    } else if (mouse.button === Qt.RightButton) {
                        contextMenu.popup()
                    }
                }
            }

            Menu {
                id: contextMenu
                MenuItem {
                    text: qsTr("Play next")
                    onTriggered: root.hasLocalTracks
                        ? Daemon.addLocalTrackToQueue(row.trackId, true)
                        : Daemon.addToQueue(row.trackId, true)
                }
                MenuItem {
                    text: qsTr("Add to queue")
                    onTriggered: root.hasLocalTracks
                        ? Daemon.addLocalTrackToQueue(row.trackId, false)
                        : Daemon.addToQueue(row.trackId, false)
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: root.showEmptyState && root.empty
        spacing: Theme.space2

        Icon { Layout.alignment: Qt.AlignHCenter; name: root.emptyIcon; size: 28; color: Theme.fgSurfaceVariant }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.emptyMessage
            color: Theme.fgSurfaceVariant
            font: Theme.fontBodyMedium
        }
        STButton {
            Layout.alignment: Qt.AlignHCenter
            visible: root.emptyAction !== ""
            text: root.emptyAction
            variant: "tonal"
            onClicked: root.emptyActionClicked()
        }
    }

    function formatTime(ms) {
        if (!ms || ms <= 0) return "—:—"
        var s = Math.floor(ms / 1000)
        var m = Math.floor(s / 60)
        s = s % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }
}
