// components/STButton.qml — reusable Material 3-style pill button.
//
// Variants: "filled" | "tonal" | "outlined" | "text" | "elevated".
// Height 40px, full-pill radius, 100ms color transition. Icon (when set) is
// drawn with the shared Icon component (monochrome Material Symbols glyphs).
//
// BUGFIX: width used to be estimated by a fixed per-character constant
// (monospace assumption) which badly mis-sizes variable-width text. Now the
// width comes from TextMetrics so it is exact for any font.

import QtQuick
import theme 1.0

Item {
    id: root

    property string variant: "filled" // filled | tonal | outlined | text | elevated
    property string text: ""
    property string iconName: ""
    property real iconSize: 20
    property color color: Theme.primary
    property bool pressed: false
    property bool hovered: false

    property bool hoverEnabled: true

    implicitWidth: Math.max(64, textMetrics.advanceWidth + (iconName ? iconSize + Theme.spacingSm : 0) + Theme.spacingLg * 2)
    implicitHeight: 40
    height: 40
    width: implicitWidth

    signal clicked()

    TextMetrics {
        id: textMetrics
        font: Theme.fontLabelLarge
        text: root.text
    }

    QtObject {
        id: _d
        function bg(): color {
            switch (variant) {
            case "filled":   return Theme.primary
            case "tonal":    return Theme.secondaryContainer
            case "elevated": return Theme.surfaceContainerHigh
            case "outlined":
            case "text":     return "transparent"
            }
            return Theme.primary
        }

        function fg(): color {
            switch (variant) {
                case "filled":   return Theme.onPrimary
                case "tonal":    return Theme.onSecondaryContainer
                case "elevated": return Theme.onSurface
                case "outlined": return Theme.primary
                case "text":     return Theme.primary
            }
            return Theme.onPrimary
        }
    }

    Rectangle {
        id: bgLayer
        anchors.fill: parent
        radius: Theme.radiusFull
        color: _d.bg()
        opacity: root.enabled ? 1 : 0.5
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        border.width: variant === "outlined" ? 1 : 0
        border.color: Theme.outlineStrong
    }

    // Hover / press tonal overlay
    Rectangle {
        id: overlay
        anchors.fill: parent
        radius: Theme.radiusFull
        color: root.pressed ? Theme.primaryContainer : "white"
        opacity: root.enabled ? (root.pressed ? 0.35 : (root.hovered ? 0.18 : 0)) : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
    }

    Row {
        anchors.centerIn: parent
        spacing: Theme.spacingSm

        Icon {
            visible: root.iconName !== ""
            name: root.iconName
            size: root.iconSize
            color: root.enabled ? _d.fg() : Theme.onSurfaceVariant
        }

        Text {
            visible: root.text !== ""
            text: root.text
            color: root.enabled ? _d.fg() : Theme.onSurfaceVariant
            font: Theme.fontLabelLarge
            verticalAlignment: Text.AlignVCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: root.hoverEnabled
        onPressedChanged: root.pressed = pressed
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: root.clicked()
    }
}
