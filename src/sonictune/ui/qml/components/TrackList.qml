// components/TrackList.qml — numbered track list with play/add-to-queue.
//
// Expects a `tracks` model: list of { video_id, title, artist, album,
// duration_ms, thumbnail_url }.
//
// Numbered indices render in the mono font; hovering swaps the number for
// a play glyph. The active (currently playing) row gets a primaryContainer
// background.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    color: "transparent"
    implicitHeight: list.contentHeight

    property var tracks: []
    property string currentVideoId: ""
    property bool showEmptyState: true
    property string emptyMessage: qsTr("Nothing here yet")

    signal playTrack(string videoId)
    signal addToQueue(string videoId)

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        model: root.tracks
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index

            width: list.width
            height: 60
            readonly property bool isCurrent: modelData.video_id === root.currentVideoId
            radius: Theme.radiusMd
            color: isCurrent
                ? Theme.primaryContainer
                : (mouseArea.containsMouse ? Theme.surfaceContainer : "transparent")

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingMd
                anchors.rightMargin: Theme.spacingMd
                spacing: Theme.spacingSm

                // Numbered index (mono) -> play glyph on hover/current.
                Item {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 40

                    Text {
                        anchors.centerIn: parent
                        visible: !mouseArea.containsMouse && !row.isCurrent
                        text: (row.index + 1) + "."
                        color: Theme.onSurfaceMuted
                        font: Theme.fontMono
                    }

                    Icon {
                        anchors.centerIn: parent
                        visible: mouseArea.containsMouse || row.isCurrent
                        name: "play"
                        size: 16
                        color: row.isCurrent ? Theme.primary : Theme.onSurface
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
                        source: row.modelData.thumbnail_url
                            ? "image://art/" + encodeURIComponent(row.modelData.thumbnail_url)
                            : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    Icon {
                        anchors.centerIn: parent
                        visible: !row.modelData.thumbnail_url
                        name: "note"
                        size: 16
                        color: Theme.onSurfaceVariant
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.title || qsTr("Unknown title")
                        color: row.isCurrent ? Theme.onPrimaryContainer : Theme.onSurface
                        font: Theme.fontBodyLarge
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.artist + (row.modelData.album ? "  ·  " + row.modelData.album : "")
                        color: row.isCurrent ? Theme.onSurfaceVariant : Theme.onSurfaceVariant
                        font: Theme.fontBodySmall
                        elide: Text.ElideRight
                    }
                }

                Text {
                    text: root.formatTime(row.modelData.duration_ms || 0)
                    color: Theme.onSurfaceMuted
                    font: Theme.fontMono
                    Layout.preferredWidth: 44
                    horizontalAlignment: Text.AlignRight
                }

                Item {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    visible: mouseArea.containsMouse

                    Icon { anchors.centerIn: parent; name: "add"; size: 16; color: Theme.onSurfaceVariant }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.addToQueue(row.modelData.video_id)
                    }
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.LeftButton) {
                        root.playTrack(row.modelData.video_id)
                    } else if (mouse.button === Qt.RightButton) {
                        contextMenu.popup()
                    }
                }
            }

            Menu {
                id: contextMenu
                MenuItem {
                    text: qsTr("Play next")
                    onTriggered: Daemon.addToQueue(row.modelData.video_id, true)
                }
                MenuItem {
                    text: qsTr("Add to queue")
                    onTriggered: Daemon.addToQueue(row.modelData.video_id, false)
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: root.showEmptyState && root.tracks.length === 0
        spacing: Theme.spacingSm

        Icon { Layout.alignment: Qt.AlignHCenter; name: "note"; size: 28; color: Theme.onSurfaceVariant }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.emptyMessage
            color: Theme.onSurfaceVariant
            font: Theme.fontBodyMedium
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
