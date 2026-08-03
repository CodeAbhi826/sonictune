// components/STSlider.qml — Material 3-style seek slider.
//
// BUGFIX: previously this was a hand-rolled drag implementation that called
// a non-existent function, so dragging a slider was a hard QML runtime
// error and every slider was dead. Now it's a real QtQuick.Controls.Slider
// with a styled track/handle; consumers use the standard `onMoved` signal.
//
// Track height 4px (radius 2px), active track in Theme.primary, inactive
// track in Theme.outline. Handle 16px circle expanding to 20px while
// pressed (100ms OutBack).

import QtQuick
import QtQuick.Controls
import theme 1.0

Slider {
    id: control

    implicitHeight: 20

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: 4
        radius: 2
        color: Theme.outline

        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: 2
            color: Theme.primary
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.pressed ? 20 : 16
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
}
