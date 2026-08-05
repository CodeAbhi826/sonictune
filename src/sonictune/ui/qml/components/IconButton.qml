// components/IconButton.qml — round icon button used in the player bar,
// now-playing transport, and elsewhere. Rebuilt on top of Icon.qml with
// Material 3 surface-tint states and a minimum 40px touch target.
//
// Legacy properties kept for backwards compatibility: `icon` (alias of
// `iconName`), `highlighted`, `prominent`, `diameter`.

import QtQuick
import QtQuick.Controls
import theme 1.0

Rectangle {
    id: root

    property string icon: "play"
    property string iconName: ""
    property bool highlighted: false
    property real diameter: 36
    property real iconSize: 20
    property bool prominent: false
    property string toolTip: ""
    property bool checkable: false
    property bool checked: false

    signal clicked()

    width: Math.max(40, diameter)
    height: Math.max(40, diameter)
    implicitWidth: width
    implicitHeight: height
    radius: width / 2
    color: !root.enabled
        ? Theme.surfaceContainer
        : root.prominent
            ? Theme.primary
            : root.checked || root.highlighted
                ? Theme.primaryContainer
                : ma.pressed
                    ? Theme.surfaceContainerHighest
                    : ma.containsMouse
                        ? Theme.surfaceContainerHigh
                        : "transparent"

    Behavior on color {
        enabled: !Theme.reducedMotion
        ColorAnimation { duration: Theme.durFast }
    }

    opacity: root.enabled ? 1.0 : 0.5
    scale: ma.pressed && root.enabled ? 0.92 : 1.0
    Behavior on scale {
        enabled: !Theme.reducedMotion
        NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic }
    }

    Icon {
        anchors.centerIn: parent
        name: root.iconName !== "" ? root.iconName : root.icon
        size: root.iconSize
        color: !root.enabled
            ? Theme.fgSurfaceVariant
            : root.prominent
                ? Theme.fgPrimary
                : root.checked || root.highlighted
                    ? Theme.fgPrimaryContainer
                    : Theme.fgSurface
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.checkable)
                root.checked = !root.checked
            root.clicked()
        }
    }

    ToolTip.visible: ma.containsMouse && root.toolTip !== "" && root.enabled
    ToolTip.text: root.toolTip
    ToolTip.delay: 600
}
