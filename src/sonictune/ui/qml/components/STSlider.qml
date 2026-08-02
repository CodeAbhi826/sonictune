// components/STSlider.qml — Material 3-style slider.
//
// Track height 4px (radius 2px), active track in Theme.primary, inactive
// track in surfaceContainerHigh. Handle 16px circle expanding to 20px while
// pressed (100ms OutBack).

import QtQuick
import theme 1.0

Item {
    id: root

    property real from: 0.0
    property real to: 1.0
    property real value: 0.0
    property bool isActive: to > from

    property real handleSize: 16
    property real handlePressedSize: 20
    property bool pressed: false

    signal valueChanged(real value)
    signal moved()

    height: 20
    width: 200

    readonly property real _t: isActive ? (value - from) / (to - from) : 0.0

    Rectangle {
        id: trackBg
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 4
        radius: 2
        color: Theme.surfaceContainerHigh
    }

    Rectangle {
        id: trackActive
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: trackBg.x + root._t * root.width
        height: 4
        radius: 2
        color: Theme.primary
    }

    Rectangle {
        id: handle
        x: root._t * root.width - width / 2
        y: (parent.height - height) / 2
        width: root.pressed ? root.handlePressedSize : root.handleSize
        height: width
        radius: width / 2
        color: Theme.primary
        Behavior on width { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutBack } }

        Rectangle {
            anchors.centerIn: parent
            width: 4
            height: 4
            radius: 2
            color: Theme.onPrimary
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onPressedChanged: { root.pressed = pressed; if (pressed) _setFromMouse(mouse.x) }
        onPositionChanged: if (pressed) _setFromMouse(mouse.x)
        onReleased: root.pressed = false
    }

    function _setFromMouse(x: real) {
        if (!isActive) return
        var t = Math.max(0, Math.min(1, x / width))
        value = from + t * (to - from)
        movedBy(value)
    }
}