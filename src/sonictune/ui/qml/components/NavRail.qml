// components/NavRail.qml — left navigation rail.
// A quiet vertical strip: mark at top, FIVE destinations below (Home,
// Search, Library, Stats, Settings). The Now Playing view is NOT a rail
// destination — it opens as a full-screen overlay from the bottom player
// bar (see main.qml).

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: navRail
    color: Theme.surface

    property int currentIndex: 0

    signal navigate(string pageName)

    readonly property var items: [
        { name: "home",       icon: "home",     label: qsTr("Home") },
        { name: "search",     icon: "search",   label: qsTr("Search") },
        { name: "library",    icon: "library",  label: qsTr("Library") },
        { name: "stats",      icon: "stats",    label: qsTr("Stats") },
        { name: "settings",   icon: "settings", label: qsTr("Settings") }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingLg
        anchors.bottomMargin: Theme.spacingMd
        spacing: Theme.spacingXs

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

        Item { Layout.preferredHeight: Theme.spacingLg }

        Repeater {
            model: navRail.items

            delegate: Item {
                id: navItem
                required property var modelData
                required property int index

                Layout.preferredWidth: navRail.width
                Layout.preferredHeight: 60

                readonly property bool active: navRail.currentIndex === index

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: navItem.active ? 24 : 0
                    radius: 2
                    color: Theme.primary
                    Behavior on height { NumberAnimation { duration: Theme.durationBase; easing.type: Theme.easingStandard } }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    radius: Theme.radiusLg
                    color: navItem.active ? Theme.surfaceElevated : (ma.containsMouse ? Theme.surfaceContainer : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Icon {
                            Layout.alignment: Qt.AlignHCenter
                            name: navItem.modelData.icon
                            size: 20
                            color: navItem.active ? Theme.primary : Theme.onSurfaceVariant
                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: navItem.modelData.label
                            font: Theme.fontLabelSmall
                            color: navItem.active ? Theme.primary : Theme.onSurfaceVariant
                        }
                    }

                    MouseArea {
                        id: ma
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
