// components/STButton.qml — reusable Material 3 pill button built on
// QtQuick.Controls.Button (so `text`, `enabled`, `pressed`, `hovered` and
// `clicked()` are all the native Control properties — nothing shadowed).
//
// Variants: "filled" | "tonal" | "outlined" (plus legacy "text" | "elevated"
// kept for compatibility). Height 40px, full-pill radius. Icon (when set) is
// drawn with the shared Icon component.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import theme 1.0

Button {
    id: root

    property string variant: "filled"
    property string iconName: ""
    property real iconSize: 20

    implicitHeight: 40
    implicitWidth: Math.max(64, textMetrics.advanceWidth
                            + (root.iconName !== "" ? root.iconSize + Theme.space2 : 0)
                            + Theme.space4 * 2)
    topPadding: 0
    bottomPadding: 0
    leftPadding: Theme.space4
    rightPadding: Theme.space4

    TextMetrics {
        id: textMetrics
        font: Theme.fontLabelLarge
        text: root.text
    }

    contentItem: RowLayout {
        spacing: root.iconName !== "" && root.text !== "" ? Theme.space2 : 0

        Icon {
            visible: root.iconName !== ""
            name: root.iconName
            size: root.iconSize
            color: _d.fg(root.enabled)
        }

        Text {
            visible: root.text !== ""
            text: root.text
            color: _d.fg(root.enabled)
            font: Theme.fontLabelLarge
            verticalAlignment: Text.AlignVCenter
        }
    }

    background: Rectangle {
        radius: Theme.radiusFull
        color: _d.bg()
        opacity: root.enabled ? 1.0 : 0.5

        Behavior on color {
            enabled: !Theme.reducedMotion
            ColorAnimation { duration: Theme.durFast }
        }

        border.width: root.variant === "outlined" ? 1 : 0
        border.color: Theme.outline

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusFull
            color: Theme.onSurface
            opacity: root.enabled ? (root.pressed ? 0.30 : (root.hovered ? 0.14 : 0)) : 0

            Behavior on opacity {
                enabled: !Theme.reducedMotion
                NumberAnimation { duration: Theme.durFast }
            }
        }
    }

    QtObject {
        id: _d

        function bg(): color {
            switch (root.variant) {
            case "filled":   return Theme.primary
            case "tonal":    return Theme.secondaryContainer
            case "elevated": return Theme.surfaceContainerHigh
            case "outlined":
            case "text":     return "transparent"
            }
            return Theme.primary
        }

        function fg(enabled): color {
            switch (root.variant) {
            case "filled":   return enabled ? Theme.onPrimary : Theme.onSurfaceVariant
            case "tonal":    return enabled ? Theme.onSecondaryContainer : Theme.onSurfaceVariant
            case "elevated": return enabled ? Theme.onSurface : Theme.onSurfaceVariant
            case "outlined": return enabled ? Theme.primary : Theme.onSurfaceVariant
            case "text":     return enabled ? Theme.primary : Theme.onSurfaceVariant
            }
            return enabled ? Theme.onPrimary : Theme.onSurfaceVariant
        }
    }
}
