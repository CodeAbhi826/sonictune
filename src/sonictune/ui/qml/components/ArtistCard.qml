// components/ArtistCard.qml — circular avatar + artist name card.
// VISUAL-FIX: tonal border highlight on hover (no GPU DropShadow).

import QtQuick
import QtQuick.Layouts
import theme 1.0

Rectangle {
    id: root

    property string name: ""
    property string thumbnailUrl: ""
    property string channelId: ""

    signal clicked(string channelId)

    width: 152
    height: 196
    color: "transparent"

    z: 1

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space2

        Rectangle {
            Layout.preferredWidth: 152
            Layout.preferredHeight: 152
            Layout.alignment: Qt.AlignHCenter
            radius: width / 2
            color: Theme.surfaceContainer

            Image {
                anchors.fill: parent
                source: root.thumbnailUrl ? "image://art/" + encodeURIComponent(root.thumbnailUrl) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: status === Image.Ready ? 1.0 : 0.0
                Behavior on opacity {
                    enabled: !Theme.reducedMotion
                    NumberAnimation { duration: 200 }
                }
            }

            Icon {
                anchors.centerIn: parent
                visible: !root.thumbnailUrl
                name: "note"
                size: 24
                color: Theme.fgSurfaceVariant
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.scrim
                opacity: ma.containsMouse ? 0.22 : 0
                Behavior on opacity {
                    enabled: !Theme.reducedMotion
                    NumberAnimation { duration: Theme.durFast }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 1.5
                border.color: Theme.primary
                opacity: ma.containsMouse ? 1 : 0
                Behavior on opacity {
                    enabled: !Theme.reducedMotion
                    NumberAnimation { duration: Theme.durFast }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.name
            color: Theme.fgSurface
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
        acceptedButtons: Qt.LeftButton
        onClicked: root.clicked(root.channelId)
    }
}
