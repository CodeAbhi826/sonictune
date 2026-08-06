// pages/SettingsAboutPage.qml — about sub-page.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"
import "../router"

Item {
    id: page

    property string pageTitle: qsTr("About")

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space4

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.space2
            Layout.rightMargin: Theme.space2
            Layout.topMargin: Theme.space2
            spacing: Theme.space2

            IconButton {
                iconName: "chevronLeft"
                iconSize: 18
                toolTip: qsTr("Back")
                onClicked: Router.popPage()
            }

            Text {
                Layout.fillWidth: true
                text: page.pageTitle
                color: Theme.fgSurface
                font: Theme.fontHeadlineSmall
                elide: Text.ElideRight
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                id: column
                width: page.width
                spacing: Theme.space3
                anchors.leftMargin: Theme.space4
                anchors.rightMargin: Theme.space4

                Icon {
                    Layout.alignment: Qt.AlignHCenter
                    name: "settings"
                    size: 48
                    color: Theme.fgSurfaceVariant
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("SonicTune")
                    color: Theme.fgSurface
                    font: Theme.fontHeadlineSmall
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    text: qsTr("Version %1").arg(typeof AppVersion !== "undefined" ? AppVersion : "0.1.0")
                    color: Theme.fgSurfaceVariant
                    font: Theme.fontBodySmall
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.space4
                    text: qsTr("A native YouTube Music client for Linux, built with PySide6 and mpv.")
                    color: Theme.fgSurfaceVariant
                    font: Theme.fontBodyMedium
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.space4
                    Layout.preferredHeight: 64
                    radius: Theme.radiusMd
                    color: Theme.surfaceContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.space4
                        spacing: Theme.space3

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text { text: qsTr("Project"); color: Theme.fgSurface; font: Theme.fontBodyMedium }
                            Text { text: qsTr("Open source"); color: Theme.fgSurfaceVariant; font: Theme.fontBodySmall }
                        }
                    }
                }

                Item { Layout.preferredHeight: Theme.space4 }
            }
        }
    }
}
