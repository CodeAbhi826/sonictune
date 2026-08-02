// components/IconButton.qml — round icon button used in the player bar,
// now-playing transport, and elsewhere. Rebuilt on top of Icon.qml
// (was emoji-in-a-circle before).

import QtQuick
import "../theme"

Rectangle {
    id: root

    property string icon: "play"
    property bool highlighted: false
    property real diameter: 36
    property real iconSize: 16
    property bool prominent: false

    signal clicked()

    width: diameter
    height: diameter
    radius: diameter / 2
    color: root.prominent
        ? Theme.primary
        : (root.highlighted ? Theme.primaryContainer : (ma.containsMouse ? Theme.surfaceContainerHigh : "transparent"))

    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

    scale: ma.pressed ? 0.92 : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easingStandard } }

    Icon {
        anchors.centerIn: parent
        name: root.icon
        size: root.iconSize
        color: root.prominent ? Theme.onPrimary : (root.highlighted ? Theme.primary : Theme.onSurface)
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
