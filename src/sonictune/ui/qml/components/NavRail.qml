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
    property var stackView: null

    signal navigate(string pageUrl)

    readonly property var items: [
        { name: "home",     url: "../pages/HomePage.qml",     icon: "home",     label: qsTr("Home") },
        { name: "search",   url: "../pages/SearchPage.qml",   icon: "search",   label: qsTr("Search") },
        { name: "library",  url: "../pages/LibraryPage.qml",  icon: "library",  label: qsTr("Library") },
        { name: "local",    url: "../pages/LocalLibraryPage.qml", icon: "musicNote", label: qsTr("Local") },
        { name: "stats",    url: "../pages/StatsPage.qml",    icon: "stats",    label: qsTr("Stats") },
        { name: "settings", url: "../pages/SettingsPage.qml", icon: "settings", label: qsTr("Settings") }
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

                Icon { anchors.centerIn: parent; name: "note"; size: 20; color: Theme.fgPrimary }
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
                            color: navItem.active ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
                            Behavior on color {
                                enabled: !Theme.reducedMotion
                                ColorAnimation { duration: Theme.durFast }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: navItem.modelData.label
                            font: Theme.fontLabelMedium
                            color: navItem.active ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
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
                        onClicked: {
                            if (navRail.stackView) {
                                var targetUrl = navItem.modelData.url
                                if (navRail.stackView.currentItem && navRail.stackView.currentItem.url === targetUrl) {
                                    // Already on this page, pop to root
                                    navRail.stackView.pop(null, navRail.stackView.Immediate)
                                } else {
                                    // Navigate to the page
                                    navRail.stackView.replace(targetUrl)
                                }
                            } else {
                                navRail.navigate(navItem.modelData.url)
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
