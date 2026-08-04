// components/AlbumCard.qml — album card: 180x220, 16px-radius art with a
// hover play overlay and a border-highlight lift on hover.

import QtQuick
import QtQuick.Layouts
import theme 1.0

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

    scale: ma.pressed ? 0.97 : (ma.containsMouse ? 1.02 : 1.0)
    Behavior on scale {
        enabled: !Theme.reducedMotion
        NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space1

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

            Rectangle {
                anchors.fill: parent
                color: Theme.scrim
                opacity: ma.containsMouse ? 0.5 : 0
                Behavior on opacity {
                    enabled: !Theme.reducedMotion
                    NumberAnimation { duration: Theme.durFast }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusLg
                color: "transparent"
                border.width: 1.5
                border.color: Theme.primary
                opacity: ma.containsMouse ? 1 : 0
                Behavior on opacity {
                    enabled: !Theme.reducedMotion
                    NumberAnimation { duration: Theme.durFast }
                }
            }

            Rectangle {
                width: 44
                height: 44
                radius: 22
                anchors.centerIn: parent
                color: Theme.primary
                opacity: ma.containsMouse ? 1 : 0
                scale: ma.containsMouse ? 1.0 : 0.8
                Behavior on opacity {
                    enabled: !Theme.reducedMotion
                    NumberAnimation { duration: Theme.durFast }
                }
                Behavior on scale {
                    enabled: !Theme.reducedMotion
                    NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic }
                }

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
