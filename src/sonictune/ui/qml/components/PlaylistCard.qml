// components/PlaylistCard.qml — square card for playlists.

import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: card

    property string title: ""
    property string subtitle: ""
    property string thumbnailUrl: ""
    property string playlistId: ""
    property int trackCount: 0

    signal clicked(string playlistId)

    width: 168
    height: 224
    color: "transparent"

    scale: ma.pressed ? 0.98 : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.durationFast } }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingXs

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 168
            radius: Theme.radiusMd
            color: Theme.surfaceContainer
            clip: true

            Image {
                anchors.fill: parent
                source: card.thumbnailUrl ? "image://art/" + encodeURIComponent(card.thumbnailUrl) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Icon {
                anchors.centerIn: parent
                visible: !card.thumbnailUrl
                name: "queue"
                size: 24
                color: Theme.onSurfaceVariant
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.scrim
                opacity: ma.containsMouse ? 0.28 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
            }
        }

        Text {
            Layout.fillWidth: true
            text: card.title
            color: Theme.onSurface
            font: Theme.fontTitleMedium
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("%n track(s)", "", card.trackCount)
            color: Theme.onSurfaceVariant
            font: Theme.fontBodySmall
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: card.clicked(card.playlistId)
    }
}
