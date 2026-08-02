// components/ArtistCard.qml — circular avatar + artist name card.

import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: card

    property string name: ""
    property string thumbnailUrl: ""
    property string channelId: ""

    signal clicked(string channelId)

    width: 152
    height: 196
    color: "transparent"

    scale: ma.pressed ? 0.98 : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.durationFast } }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingSm

        Rectangle {
            Layout.preferredWidth: 152
            Layout.preferredHeight: 152
            Layout.alignment: Qt.AlignHCenter
            radius: width / 2
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
                name: "note"
                size: 24
                color: Theme.onSurfaceVariant
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.scrim
                opacity: ma.containsMouse ? 0.22 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
            }
        }

        Text {
            Layout.fillWidth: true
            text: card.name
            color: Theme.onSurface
            font: Theme.fontTitleMedium
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: card.clicked(card.channelId)
    }
}
