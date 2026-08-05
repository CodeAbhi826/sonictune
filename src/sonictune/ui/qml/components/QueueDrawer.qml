// components/QueueDrawer.qml — right-hand drawer showing the play queue
// (Material 3 Dark). A single top-level Connections block keeps the Daemon
// subscriptions managed by Qt, so repeated opens never stack handlers.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Drawer {
    id: queueDrawer
    edge: Qt.RightEdge
    width: 380
    height: parent.height

    background: Rectangle { color: Theme.surfaceContainerHigh }

    property var queue: ({})
    property string currentVideoId: ""

    Connections {
        target: Daemon
        function onQueueReceived(q) { queueDrawer.queue = q || {} }
        function onStatusReceived(s) {
            var t = (s || {}).track || {}
            queueDrawer.currentVideoId = t.videoId !== undefined ? t.videoId : (t.video_id || "")
        }
        function onTrackChanged(t) {
            t = t || {}
            queueDrawer.currentVideoId = t.videoId !== undefined ? t.videoId : (t.video_id || "")
        }
        function onQueueChanged() { if (queueDrawer.visible) queueDrawer.refresh() }
    }

    function refresh() {
        Daemon.getQueue()
        Daemon.getStatus()
    }

    function _videoId(t) {
        if (!t) return ""
        if (t.videoId !== undefined) return t.videoId
        return t.video_id || ""
    }

    onOpened: refresh()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space4
        spacing: Theme.space3

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: qsTr("Queue")
                color: Theme.fgSurface
                font: Theme.fontTitleLarge
            }

            Item { Layout.fillWidth: true }

            Text {
                text: qsTr("%n track(s)", "", (queueDrawer.queue.tracks || []).length)
                color: Theme.fgSurfaceVariant
                font: Theme.fontBodySmall
            }

            IconButton {
                iconName: "close"
                iconSize: 18
                toolTip: qsTr("Close")
                onClicked: queueDrawer.close()
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.outline }

        ListView {
            id: queueList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: queueDrawer.queue.tracks || []
            spacing: Theme.space1
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: Theme.listCacheBuffer

            delegate: Item {
                id: queueRow
                required property var modelData
                required property int index

                width: queueList.width
                height: 56

                readonly property bool isCurrent: queueDrawer._videoId(queueRow.modelData) === queueDrawer.currentVideoId

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSm
                    color: queueRow.isCurrent
                        ? Theme.primaryContainer
                        : (rowMa.containsMouse ? Theme.surfaceContainerHigh : "transparent")
                    Behavior on color {
                        enabled: !Theme.reducedMotion
                        ColorAnimation { duration: Theme.durFast }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.space3
                        anchors.rightMargin: Theme.space2
                        spacing: Theme.space3

                        Text {
                            Layout.preferredWidth: 24
                            text: queueRow.isCurrent ? "" : (queueRow.index + 1)
                            color: Theme.fgSurfaceVariant
                            font: Theme.fontMono
                            horizontalAlignment: Text.AlignRight
                        }

                        Icon {
                            visible: queueRow.isCurrent
                            Layout.preferredWidth: 24
                            name: "note"
                            size: 13
                            color: Theme.primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: queueRow.modelData.title || ""
                                color: queueRow.isCurrent ? Theme.fgPrimaryContainer : Theme.fgSurface
                                font: Theme.fontBodyMedium
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: queueRow.modelData.artist || ""
                                color: Theme.fgSurfaceVariant
                                font: Theme.fontBodySmall
                                elide: Text.ElideRight
                            }
                        }

                        IconButton {
                            iconName: "close"
                            iconSize: 14
                            toolTip: qsTr("Remove from queue")
                            visible: rowMa.containsMouse || queueRow.isCurrent
                            onClicked: Daemon.removeFromQueue(queueRow.index)
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: queueList.count === 0
                spacing: Theme.space2

                Icon {
                    Layout.alignment: Qt.AlignHCenter
                    name: "queue_music"
                    size: 26
                    color: Theme.fgSurfaceVariant
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Queue is empty")
                    color: Theme.fgSurfaceVariant
                    font: Theme.fontBodyMedium
                }
            }
        }
    }
}
