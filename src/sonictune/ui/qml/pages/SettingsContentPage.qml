// pages/SettingsContentPage.qml — content & downloads sub-page.

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "../theme"
import "../components"
import "../router"

Item {
    id: page
    objectName: "settingsContent"

    property string pageTitle: qsTr("Content")

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

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Downloads")
                    color: Theme.fgSurface
                    font: Theme.fontTitleMedium
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    radius: Theme.radiusMd
                    color: Theme.surfaceContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.space4
                        spacing: Theme.space3

                        Icon { name: "download"; size: 18; color: Theme.fgSurfaceVariant }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text { text: qsTr("Offline downloads"); color: Theme.fgSurface; font: Theme.fontBodyMedium }
                            Text { text: qsTr("Coming soon"); color: Theme.fgSurfaceVariant; font: Theme.fontBodySmall }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.space2
                    text: qsTr("Offline playback is planned for a future release. Downloaded tracks will appear here and on the Library page.")
                    color: Theme.fgSurfaceVariant
                    font: Theme.fontBodySmall
                    wrapMode: Text.Wrap
                }

                Item { Layout.preferredHeight: Theme.space4 }
            }
        }
    }
}
