// components/STSlider.qml — Material 3-style seek slider built on a real
// QtQuick.Controls.Slider. `from`, `to`, `value`, `live` and `snapMode` are
// the native Slider properties; `valueChanged` / `moved` work normally.
//
// Track height 4px (radius 2px), filled track in Theme.primary, unfilled in
// Theme.playerProgressBg. Handle 16px circle expanding to 20px while
// pressed (OutBack easing, gated on reducedMotion). Touch target >= 32px.

import QtQuick
import QtQuick.Controls
import theme 1.0

Slider {
    id: control

    implicitHeight: 32

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: 4
        radius: 2
        color: Theme.playerProgressBg

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

        Behavior on width {
            enabled: !Theme.reducedMotion
            NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutBack }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 4
            height: 4
            radius: 2
            color: Theme.onPrimary
        }
    }
}
