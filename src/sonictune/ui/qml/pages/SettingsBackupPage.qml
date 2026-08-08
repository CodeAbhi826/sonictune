// pages/SettingsBackupPage.qml — backup & cache sub-page.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"
import "../router"

Item {
    id: page
    objectName: "settingsBackup"

    property string pageTitle: qsTr("Backup")
    property real audioCacheBytes: 0

    Connections {
        target: Daemon
        function onAudioCacheSizeReceived(b) { page.audioCacheBytes = b }
        function onAudioCacheCleared() {
            page.audioCacheBytes = 0
            toast.show(qsTr("Audio cache cleared"))
        }
    }

    Component.onCompleted: Daemon.getAudioCacheSize()

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

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 72
                    radius: Theme.radiusLg
                    color: Theme.surfaceContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.space4
                        spacing: Theme.space3

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text { text: qsTr("Downloaded audio cache"); color: Theme.fgSurface; font: Theme.fontTitleMedium }
                            Text {
                                text: page.formatBytes(page.audioCacheBytes)
                                color: Theme.fgSurfaceVariant
                                font: Theme.fontBodySmall
                            }
                        }

                        STButton {
                            text: qsTr("Clear cache")
                            variant: "tonal"
                            onClicked: Daemon.clearAudioCache()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Automated backups of settings and library data are planned for a future release.")
                    color: Theme.fgSurfaceVariant
                    font: Theme.fontBodySmall
                    wrapMode: Text.Wrap
                }

                Item { Layout.preferredHeight: Theme.space4 }
            }
        }
    }

    ErrorToast { id: toast }

    function formatBytes(bytes) {
        if (!bytes || bytes <= 0) return qsTr("0 MB")
        var mb = bytes / (1024 * 1024)
        if (mb < 1024) return mb.toFixed(1) + " MB"
        return (mb / 1024).toFixed(2) + " GB"
    }
}
