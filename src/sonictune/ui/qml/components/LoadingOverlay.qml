// components/LoadingOverlay.qml — full-page loading veil with a message.
// The spinning ring is a Canvas arc; it rotates only when motion is allowed
// (Theme.reducedMotion shows a static ring instead).

import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: overlay
    anchors.fill: parent
    visible: opacity > 0
    opacity: 0
    enabled: visible

    property string message: qsTr("Loading…")

    Behavior on opacity {
        enabled: !Theme.reducedMotion
        NumberAnimation { duration: Theme.durNormal }
    }

    function show(msg) {
        if (msg) message = msg
        opacity = 1
    }

    function hide() {
        opacity = 0
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        opacity: 0.6
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.space4
        visible: overlay.opacity > 0

        Canvas {
            id: spinner
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            width: 44
            height: 44
            renderStrategy: Canvas.Cooperative

            property real sweep: Math.PI * 1.5

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.lineCap = "round"
                ctx.lineWidth = 4
                ctx.strokeStyle = Theme.primary
                ctx.beginPath()
                ctx.arc(width / 2, height / 2, width / 2 - 5, 0, spinner.sweep, false)
                ctx.stroke()
            }

            Connections {
                target: Theme
                function onReducedMotionChanged() {
                    spinner.sweep = Theme.reducedMotion ? Math.PI * 2 : Math.PI * 1.5
                    spinner.requestPaint()
                }
            }

            Component.onCompleted: {
                spinner.sweep = Theme.reducedMotion ? Math.PI * 2 : Math.PI * 1.5
            }

            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                running: overlay.opacity > 0 && !Theme.reducedMotion
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: overlay.message
            color: Theme.fgSurface
            font: Theme.fontBodyLarge
        }
    }
}
