// components/QueueDrawer.qml — right-hand drawer showing the play queue.
//
// BUGFIX: the previous version called Daemon.queueReceived.connect(...) and
// Daemon.statusReceived.connect(...) fresh inside refresh() every single
// time the drawer opened, without ever disconnecting the old ones (the
// statusReceived one tried to self-disconnect via `arguments.callee`, which
// is deprecated/unreliable in QML's JS engine). Repeated opens accumulated
// handler after handler for the life of the window. Using a top-level
// Connections block instead means Qt manages the single subscription for
// us — opening the drawer just re-requests fresh data, nothing accumulates.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import "../theme"

Drawer {
    id: queueDrawer
    edge: Qt.RightEdge
    width: 380
    height: parent.height

    background: Rectangle { color: Theme.surface }

    property var queue: ({})
    property string currentVideoId: ""

    Connections {
        target: Daemon
        function onQueueReceived(q) { queueDrawer.queue = q || {} }
        function onStatusReceived(s) { queueDrawer.currentVideoId = (s.track || {}).video_id || "" }
        function onTrackChanged(t) { queueDrawer.currentVideoId = (t || {}).video_id || "" }
        function onQueueChanged() { if (queueDrawer.visible) queueDrawer.refresh() }
    }

    function refresh() {
        Daemon.getQueue()
        Daemon.getStatus()
    }

    onOpened: refresh()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingSm

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: qsTr("Queue")
                color: Theme.onSurface
                font: Theme.fontTitleLarge
            }

            Item { Layout.fillWidth: true }

            Text {
                text: qsTr("%n track(s)", "", (queueDrawer.queue.tracks || []).length)
                color: Theme.onSurfaceVariant
                font: Theme.fontBodySmall
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            Button {
                text: qsTr("Clear")
                flat: true
                onClicked: Daemon.clearQueue()
            }

            Button {
                text: queueDrawer.queue.shuffle ? qsTr("Shuffle: On") : qsTr("Shuffle: Off")
                flat: true
                highlighted: queueDrawer.queue.shuffle === true
                onClicked: Daemon.setShuffle(!queueDrawer.queue.shuffle)
            }

            Button {
                property string mode: queueDrawer.queue.repeat || "off"
                text: qsTr("Repeat: %1").arg(mode)
                flat: true
                highlighted: mode !== "off"
                onClicked: {
                    var next = mode === "off" ? "all" : mode === "all" ? "one" : "off"
                    Daemon.setRepeat(next)
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.outline }

        ListView {
            id: queueList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: queueDrawer.queue.tracks || []
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: queueRow
                required property var modelData
                required property int index

                width: queueList.width
                height: 52
                readonly property bool isCurrent: modelData.video_id === queueDrawer.currentVideoId

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: Theme.radiusSm
                    color: queueRow.isCurrent
                        ? Theme.primaryContainer
                        : (ma.containsMouse ? Theme.surfaceContainer : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingSm
                        anchors.rightMargin: Theme.spacingSm
                        spacing: Theme.spacingSm

                        Text {
                            Layout.preferredWidth: 22
                            text: queueRow.isCurrent ? "" : (queueRow.index + 1)
                            color: Theme.onSurfaceVariant
                            font: Theme.fontMono
                            horizontalAlignment: Text.AlignRight
                        }
                        Icon {
                            visible: queueRow.isCurrent
                            Layout.preferredWidth: 22
                            name: "note"
                            size: 13
                            color: Theme.primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: queueRow.modelData.title
                                color: queueRow.isCurrent ? Theme.primary : Theme.onSurface
                                font: Theme.fontBodyMedium
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: queueRow.modelData.artist
                                color: Theme.onSurfaceVariant
                                font: Theme.fontBodySmall
                                elide: Text.ElideRight
                            }
                        }

                        Item {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            visible: ma.containsMouse

                            Icon { anchors.centerIn: parent; name: "close"; size: 12; color: Theme.onSurfaceVariant }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Daemon.removeFromQueue(queueRow.index)
                            }
                        }
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onDoubleClicked: Daemon.jumpTo(queueRow.index)
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: queueList.count === 0
                spacing: Theme.spacingSm
                Icon { Layout.alignment: Qt.AlignHCenter; name: "queue"; size: 26; color: Theme.onSurfaceVariant }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Queue is empty")
                    color: Theme.onSurfaceVariant
                    font: Theme.fontBodyMedium
                }
            }
        }
    }
}
