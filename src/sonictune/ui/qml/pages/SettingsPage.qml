// pages/SettingsPage.qml — account, appearance, and cache settings.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Dialogs
import "../theme"
import "../components"

Item {
    id: settingsPage

    property bool authenticated: false
    property real audioCacheBytes: 0

    Connections {
        target: Daemon
        function onAuthChanged(a) { settingsPage.authenticated = a }
        function onAudioCacheSizeReceived(b) { settingsPage.audioCacheBytes = b }
        function onAudioCacheCleared() { settingsPage.audioCacheBytes = 0; toast.show(qsTr("Audio cache cleared")) }
        function onImportCookiesCompleted(success) {
            toast.show(success ? qsTr("Cookies imported — signed in") : qsTr("Couldn't import cookies"))
        }
        function onImportCookiesError(err) { toast.show(qsTr("Import failed: %1").arg(err)) }
    }

    Component.onCompleted: {
        settingsPage.authenticated = Daemon.isAuthenticated()
        Daemon.getAudioCacheSize()
    }

    OAuthDialog {
        id: oauthDialog
        onOauthComplete: settingsPage.authenticated = true
    }

    FileDialog {
        id: cookieDialog
        title: qsTr("Select exported cookies.txt")
        nameFilters: [qsTr("Text files (*.txt)"), qsTr("All files (*)")]
        onAccepted: Daemon.importCookies(selectedFile.toString().replace("file://", ""))
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: Math.min(560, settingsPage.width - Theme.spacingLg * 2)
            x: Theme.spacingLg
            spacing: Theme.spacingXl

            Text { text: qsTr("Settings"); color: Theme.onSurface; font: Theme.fontHeadlineMedium; Layout.topMargin: Theme.spacingLg }

            // --- Account ---------------------------------------------------
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm

                Text { text: qsTr("Account"); color: Theme.onSurfaceVariant; font: Theme.fontLabelSmall }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 72
                    radius: Theme.radiusMd
                    color: Theme.surfaceContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMd
                        spacing: Theme.spacingSm

                        Icon {
                            name: settingsPage.authenticated ? "check" : "warning"
                            size: 16
                            color: settingsPage.authenticated ? Theme.success : Theme.onSurfaceVariant
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                text: settingsPage.authenticated ? qsTr("Signed in to YouTube Music") : qsTr("Not signed in")
                                color: Theme.onSurface
                                font: Theme.fontTitleMedium
                            }
                            Text {
                                text: settingsPage.authenticated
                                    ? qsTr("Library, recommendations, and history are available")
                                    : qsTr("Sign in for your library and personalized home feed")
                                color: Theme.onSurfaceVariant
                                font: Theme.fontBodySmall
                            }
                        }

                        Button {
                            text: settingsPage.authenticated ? qsTr("Sign out") : qsTr("Sign in")
                            highlighted: !settingsPage.authenticated
                            Material.accent: Theme.primary
                            onClicked: {
                                if (settingsPage.authenticated) {
                                    Daemon.logout()
                                    settingsPage.authenticated = false
                                } else {
                                    oauthDialog.open()
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingXs
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Prefer browser cookies instead? Export them with a browser extension, then import the file.")
                        color: Theme.onSurfaceVariant
                        font: Theme.fontBodySmall
                        wrapMode: Text.Wrap
                    }
                    Button {
                        text: qsTr("Import cookies")
                        flat: true
                        onClicked: cookieDialog.open()
                    }
                }
            }

            // --- Appearance --------------------------------------------------
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm

                Text { text: qsTr("Appearance"); color: Theme.onSurfaceVariant; font: Theme.fontLabelSmall }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm

                    Repeater {
                        model: [
                            { key: "dark", label: qsTr("Dark") },
                            { key: "light", label: qsTr("Light") },
                            { key: "archive", label: qsTr("Archive") }
                        ]
                        delegate: Rectangle {
                            id: themeChip
                            required property var modelData
                            readonly property bool active: Theme.mode === themeChip.modelData.key
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: Theme.radiusMd
                            color: themeChip.active ? Theme.primaryContainer : Theme.surfaceContainer
                            border.color: themeChip.active ? Theme.primary : "transparent"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: themeChip.modelData.label
                                color: themeChip.active ? Theme.primary : Theme.onSurface
                                font: Theme.fontLabelLarge
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Theme.setTheme(themeChip.modelData.key)
                            }
                        }
                    }
                }
            }

            // --- Cache ---------------------------------------------------------
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm

                Text { text: qsTr("Cache"); color: Theme.onSurfaceVariant; font: Theme.fontLabelSmall }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    radius: Theme.radiusMd
                    color: Theme.surfaceContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMd
                        spacing: Theme.spacingSm

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text { text: qsTr("Downloaded audio cache"); color: Theme.onSurface; font: Theme.fontTitleMedium }
                            Text { text: settingsPage.formatBytes(settingsPage.audioCacheBytes); color: Theme.onSurfaceVariant; font: Theme.fontBodySmall }
                        }

                        Button {
                            text: qsTr("Clear")
                            flat: true
                            onClicked: Daemon.clearAudioCache()
                        }
                    }
                }
            }

            // --- About -----------------------------------------------------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: Theme.spacingXl
                spacing: Theme.spacingSm

                Text { text: qsTr("About"); color: Theme.onSurfaceVariant; font: Theme.fontLabelSmall }
                Text {
                    text: qsTr("SonicTune — a native YouTube Music client for Linux, built with PySide6, dbus-next, and mpv.")
                    color: Theme.onSurfaceVariant
                    font: Theme.fontBodySmall
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
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
