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
    property string currentVideoId: ""
    property bool showEmptyState: true
    property string emptyMessage: qsTr("Nothing here yet")
    property string emptyIcon: "note"
    property string emptyAction: ""

    readonly property bool empty: !root.tracks || root.tracks.length === 0

    signal playTrack(string videoId)
    signal addToQueue(string videoId)
    signal emptyActionClicked()

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
            height: 56
            readonly property bool isCurrent: modelData.video_id === root.currentVideoId
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
                        color: Theme.onSurfaceVariant
                        font: Theme.fontMono
                    }

                    Icon {
                        anchors.centerIn: parent
                        visible: mouseArea.containsMouse && !row.isCurrent
                        name: "play"
                        size: 16
                        color: Theme.onSurface
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
                        color: row.isCurrent ? Theme.onPrimaryContainer : Theme.onSurfaceVariant
                        font: Theme.fontBodySmall
                        elide: Text.ElideRight
                    }
                }

                Text {
                    text: root.formatTime(row.modelData.duration_ms || 0)
                    color: row.isCurrent ? Theme.onPrimaryContainer : Theme.onSurfaceVariant
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
        visible: root.showEmptyState && root.empty
        spacing: Theme.space2

        Icon { Layout.alignment: Qt.AlignHCenter; name: root.emptyIcon; size: 28; color: Theme.onSurfaceVariant }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.emptyMessage
            color: Theme.onSurfaceVariant
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
