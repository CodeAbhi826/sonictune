// components/NavRail.qml — left navigation rail (Material 3 Dark).
// A quiet vertical strip: mark at top, FIVE destinations below (Home,
// Search, Library, Stats, Settings). The Now Playing view is NOT a rail
// destination — it opens as a full-screen overlay from the bottom player
// bar (see main.qml).

import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: navRail
    color: Theme.surface

    implicitWidth: 88

    property int currentIndex: 0

    signal navigate(string pageName)

    readonly property var items: [
        { name: "home",     icon: "home",     label: qsTr("Home") },
        { name: "search",   icon: "search",   label: qsTr("Search") },
        { name: "library",  icon: "library",  label: qsTr("Library") },
        { name: "stats",    icon: "stats",    label: qsTr("Stats") },
        { name: "settings", icon: "settings", label: qsTr("Settings") }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Theme.space6
        anchors.bottomMargin: Theme.space4
        spacing: Theme.space1

        Item {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignHCenter

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusFull
                color: Theme.primary

                Icon { anchors.centerIn: parent; name: "note"; size: 20; color: Theme.onPrimary }
            }
        }

        Item { Layout.preferredHeight: Theme.space6 }

        Repeater {
            model: navRail.items

            delegate: Item {
                id: navItem
                required property var modelData
                required property int index

                Layout.preferredWidth: navRail.width
                Layout.preferredHeight: 56

                readonly property bool active: navRail.currentIndex === index

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space2
                    anchors.rightMargin: Theme.space2
                    radius: Theme.radiusFull
                    color: navItem.active ? Theme.primaryContainer : "transparent"
                    Behavior on color {
                        enabled: !Theme.reducedMotion
                        ColorAnimation { duration: Theme.durFast }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        Icon {
                            Layout.alignment: Qt.AlignHCenter
                            name: navItem.modelData.icon
                            size: 20
                            color: navItem.active ? Theme.onPrimaryContainer : Theme.onSurfaceVariant
                            Behavior on color {
                                enabled: !Theme.reducedMotion
                                ColorAnimation { duration: Theme.durFast }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: navItem.modelData.label
                            font: Theme.fontLabelMedium
                            color: navItem.active ? Theme.onPrimaryContainer : Theme.onSurfaceVariant
                            Behavior on color {
                                enabled: !Theme.reducedMotion
                                ColorAnimation { duration: Theme.durFast }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: navRail.navigate(navItem.modelData.name)
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
