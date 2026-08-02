// pages/StatCard.qml — small metric tile used on the Stats page.

import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"

Rectangle {
    id: card
    radius: Theme.radiusMd
    color: Theme.surfaceContainer
    Layout.preferredHeight: 96

    property string label: ""
    property string value: "0"
    property string icon: "stats"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingXs

        RowLayout {
            spacing: Theme.spacingXs
            Icon { name: card.icon; size: 14; color: Theme.onSurfaceVariant }
            Text {
                text: card.label
                color: Theme.onSurfaceVariant
                font: Theme.fontLabelSmall
            }
        }

        Item { Layout.fillHeight: true }

        Text {
            text: card.value
            color: Theme.onSurface
            font.family: Theme.fontFamilyMono
            font.pixelSize: 26
            font.weight: Font.Medium
        }
    }
}
