// pages/SettingsPage.qml — settings hub. Lists sub-pages (Appearance, Player,
// Content, Integrations, Backup, About) that are pushed onto the navigation
// stack via Router, instead of one long scrolling page.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"
import "../router"

Item {
    id: settingsPage

    property var subPages: [
        { title: qsTr("Appearance"), desc: qsTr("Animations, shadows, image cache"), icon: "tune", url: "SettingsAppearancePage.qml" },
        { title: qsTr("Player"), desc: qsTr("Audio quality, crossfade, speed, sleep timer"), icon: "play_circle", url: "SettingsPlayerPage.qml" },
        { title: qsTr("Content"), desc: qsTr("Downloads and offline playback"), icon: "download", url: "SettingsContentPage.qml" },
        { title: qsTr("Integrations"), desc: qsTr("YouTube Music sign-in and cookies"), icon: "login", url: "SettingsIntegrationsPage.qml" },
        { title: qsTr("Backup"), desc: qsTr("Audio cache management"), icon: "memory", url: "SettingsBackupPage.qml" },
        { title: qsTr("About"), desc: qsTr("Version and project info"), icon: "info", url: "SettingsAboutPage.qml" }
    ]

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space6
        anchors.rightMargin: Theme.space6
        anchors.topMargin: Theme.space6
        anchors.bottomMargin: Theme.space6
        spacing: Theme.space4

        RowLayout {
            Layout.fillWidth: true
            Text { text: qsTr("Settings"); color: Theme.fgSurface; font: Theme.fontHeadlineMedium }
            Item { Layout.fillWidth: true }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                id: sectionsColumn
                width: settingsPage.width - Theme.space6 * 2
                spacing: Theme.space3

                Repeater {
                    model: settingsPage.subPages

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72
                        radius: Theme.radiusMd
                        color: Theme.surfaceContainerLow

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.space4
                            anchors.rightMargin: Theme.space4
                            spacing: Theme.space3

                            Icon {
                                name: row.modelData.icon
                                size: 22
                                color: Theme.primary
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    text: row.modelData.title
                                    color: Theme.fgSurface
                                    font: Theme.fontTitleMedium
                                }
                                Text {
                                    text: row.modelData.desc
                                    color: Theme.fgSurfaceVariant
                                    font: Theme.fontBodySmall
                                    elide: Text.ElideRight
                                }
                            }

                            Icon {
                                name: "chevronRight"
                                size: 20
                                color: Theme.fgSurfaceVariant
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Router.pushPage(row.modelData.url)
                        }
                    }
                }

                Item { Layout.preferredHeight: Theme.space2 }
            }
        }
    }
}
