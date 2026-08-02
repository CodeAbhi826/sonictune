// components/ErrorToast.qml — bottom snackbar for transient errors.

import QtQuick
import "../theme"

Item {
    id: toast
    anchors.fill: parent

    property string message: ""
    property int durationMs: 4000

    onMessageChanged: {
        if (message) show()
    }

    function show(msg) {
        if (msg) message = msg
        fadeIn.start()
        hideTimer.interval = durationMs
        hideTimer.restart()
    }

    function hide() {
        fadeOut.start()
    }

    Rectangle {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spacingXl
        width: Math.min(480, parent.width * 0.9)
        height: 52
        radius: Theme.radiusMd
        color: Theme.surfaceContainerHigh
        border.color: Theme.error
        border.width: 1
        opacity: 0

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingMd
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: closeButton.left
            anchors.rightMargin: Theme.spacingSm
            spacing: Theme.spacingSm

            Icon { anchors.verticalCenter: parent.verticalCenter; name: "warning"; size: 16; color: Theme.error }

            Text {
                width: parent.width - 24
                text: toast.message
                color: Theme.onSurface
                font: Theme.fontBodyMedium
                elide: Text.ElideRight
            }
        }

        Item {
            id: closeButton
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingSm
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24

            Icon { anchors.centerIn: parent; name: "close"; size: 13; color: Theme.onSurfaceVariant }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: toast.hide()
            }
        }
    }

    Timer { id: hideTimer; onTriggered: toast.hide() }

    NumberAnimation {
        id: fadeIn
        target: bar
        property: "opacity"
        to: 1
        duration: Theme.durationBase
        running: false
    }

    SequentialAnimation {
        id: fadeOut
        NumberAnimation { target: bar; property: "opacity"; to: 0; duration: Theme.durationBase }
        ScriptAction { script: toast.message = "" }
    }
}
