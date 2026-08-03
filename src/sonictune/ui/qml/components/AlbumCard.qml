// components/AlbumCard.qml — ArchiveTune-style card: 180x220, 16px-radius
// art with a hover play overlay that scales in with OutBack easing.

import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: card

    property string title: ""
    property string subtitle: ""
    property string thumbnailUrl: ""
    property string browseId: ""

    signal clicked(string browseId)

    width: 180
    height: 220
    color: "transparent"

    scale: ma.pressed ? 0.97 : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.durationFast } }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingXs

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            radius: Theme.radiusLg
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
                name: "album"
                size: 30
                color: Theme.onSurfaceVariant
            }

            // Hover scrim
            Rectangle {
                anchors.fill: parent
                color: Theme.scrim
                opacity: ma.containsMouse ? 0.5 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
            }

            // Hover play button
            Rectangle {
                width: 44
                height: 44
                radius: 22
                anchors.centerIn: parent
                color: Theme.primary
                opacity: ma.containsMouse ? 1 : 0
                scale: ma.containsMouse ? 1.0 : 0.8
                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
                Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutBack } }

                Icon { anchors.centerIn: parent; anchors.horizontalCenterOffset: 1; name: "play"; size: 18; color: Theme.onPrimary }
            }
        }

        Text {
            Layout.fillWidth: true
            text: card.title
            color: Theme.onSurface
            font: Theme.fontBodyMedium
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: card.subtitle
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
        onClicked: card.clicked(card.browseId)
    }
}
