// components/AlbumCard.qml — album card: 180x220, 16px-radius art with a
// hover play overlay and a border-highlight lift on hover.
// VISUAL-FIX: fixed height prevents layout shift, DropShadow replaces
// clipped elevation, press overlay replaces heavy Material ripple shader.

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import theme 1.0

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string thumbnailUrl: ""
    property string browseId: ""

    signal clicked(string browseId)

    width: 180
    height: 220
    color: "transparent"

    z: ma.containsMouse ? 10 : 1

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
            text: root.title
            color: Theme.onSurface
            font: Theme.fontBodyMedium
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: root.subtitle
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
        acceptedButtons: Qt.LeftButton
        onClicked: root.clicked(root.browseId)
    }
}
