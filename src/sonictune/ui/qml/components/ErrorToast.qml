// components/ErrorToast.qml — bottom snackbar for transient errors
// (Material 3 error colors: errorContainer bg, onErrorContainer text).

import QtQuick
import "../theme"

Item {
    id: toast
    anchors.fill: parent

    property string message: ""
    property int durationMs: 3500

    onMessageChanged: {
        if (message) show()
    }

    function show(msg) {
        if (msg) message = msg
        bar.anchors.bottomMargin = Theme.space4
        bar.opacity = 1
        hideTimer.interval = durationMs
        hideTimer.restart()
    }

    function hide() {
        bar.anchors.bottomMargin = -bar.height
        bar.opacity = 0
    }

    Rectangle {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -52
        width: Math.min(480, parent.width * 0.9)
        height: 52
        radius: Theme.radiusMd
        color: Theme.errorContainer
        opacity: 0

        Behavior on opacity {
            enabled: !Theme.reducedMotion
            NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic }
        }

        Behavior on anchors.bottomMargin {
            enabled: !Theme.reducedMotion
            NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.space4
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: closeButton.left
            anchors.rightMargin: Theme.space2
            spacing: Theme.space2

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "warning"
                size: 16
                color: Theme.error
            }

            Text {
                width: parent.width - 24
                text: toast.message
                color: Theme.onErrorContainer
                font: Theme.fontBodyMedium
                elide: Text.ElideRight
            }
        }

        IconButton {
            id: closeButton
            anchors.right: parent.right
            anchors.rightMargin: Theme.space2
            anchors.verticalCenter: parent.verticalCenter
            iconName: "close"
            iconSize: 14
            toolTip: qsTr("Dismiss")
            onClicked: toast.hide()
        }
    }

    Timer {
        id: hideTimer
        onTriggered: toast.hide()
    }

    DragHandler {
        id: dismissDrag
        target: bar
        xAxis.enabled: true
        yAxis.enabled: false
        xAxis.minimum: -parent.width * 0.5
        xAxis.maximum: parent.width * 0.5
        onActiveChanged: {
            if (!active) {
                if (Math.abs(bar.x) > parent.width * 0.3) {
                    toast.hide()
                } else {
                    bar.x = 0
                }
            }
        }
    }
}
