// components/ArtistCard.qml — circular avatar + artist name card.
// VISUAL-FIX: DropShadow on avatar, z-index on hover, image fade-in.

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
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

    z: ma.containsMouse ? 10 : 1

    scale: ma.pressed ? 0.97 : (ma.containsMouse ? 1.02 : 1.0)
    Behavior on scale {
        enabled: !Theme.reducedMotion
        NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space2

        Rectangle {
            Layout.preferredWidth: 152
            Layout.preferredHeight: 152
            Layout.alignment: Qt.AlignHCenter
            radius: width / 2
            color: Theme.surfaceContainer

            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: ma.containsMouse ? 4 : 2
                radius: ma.containsMouse ? 12 : 6
                samples: 16
                color: Theme.shadowColor
            }

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
