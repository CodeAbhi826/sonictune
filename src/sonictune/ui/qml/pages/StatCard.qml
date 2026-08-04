// pages/StatCard.qml — Material 3 metric tile used on the Stats page.

import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"

Rectangle {
    id: card
    radius: Theme.radiusLg
    color: Theme.surfaceContainer
    implicitHeight: 116

    property string title: ""
    property string label: ""
    property string value: "0"
    property string subtitle: ""
    property string icon: "stats"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space4
        spacing: Theme.space2

        RowLayout {
            spacing: Theme.space2
            Icon { name: card.icon; size: 14; color: Theme.onSurfaceVariant }
            Text {
                text: card.title.length > 0 ? card.title : card.label
                color: Theme.onSurfaceVariant
                font: Theme.fontLabelSmall
                elide: Text.ElideRight
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

        Text {
            visible: card.subtitle.length > 0
            text: card.subtitle
            color: Theme.onSurfaceVariant
            font: Theme.fontBodySmall
            elide: Text.ElideRight
        }
    }
}
