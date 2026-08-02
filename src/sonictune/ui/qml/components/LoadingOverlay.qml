// components/LoadingOverlay.qml — full-page loading veil with a message.

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import "../theme"

Item {
    id: overlay
    anchors.fill: parent
    visible: opacity > 0
    opacity: 0
    enabled: visible

    property string message: qsTr("Loading…")

    Behavior on opacity { NumberAnimation { duration: Theme.durationBase } }

    function show(msg) {
        if (msg) message = msg
        opacity = 1
    }

    function hide() {
        opacity = 0
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.background, 0.72)
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.spacingMd
        visible: overlay.opacity > 0

        BusyIndicator {
            id: spinner
            Layout.alignment: Qt.AlignHCenter
            running: overlay.opacity > 0
            Material.accent: Theme.primary
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: overlay.message
            color: Theme.onSurface
            font: Theme.fontBodyLarge
        }
    }
}
