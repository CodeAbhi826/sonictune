// pages/SettingsPage.qml — two-pane settings: Account, Appearance,
// History Reporting, Audio cache, About.
//
// History Reporting: "Report plays to YouTube Music" toggle backed by
// Daemon.reportHistory()/setReportHistory(). On by default — when enabled,
// SonicTune reports plays back to YT Music so they count toward Recap.

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
    property bool reportHistory: true
    property int currentSection: 0

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
        settingsPage.reportHistory = Daemon.reportHistory()
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

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingLg
        spacing: Theme.spacingLg

        // --- Sidebar --------------------------------------------------------
        ColumnLayout {
            Layout.preferredWidth: 240
            Layout.alignment: Qt.AlignTop
            spacing: Theme.spacingXs

            Text { text: qsTr("Settings"); color: Theme.onSurface; font: Theme.fontHeadlineMedium; Layout.bottomMargin: Theme.spacingSm }

            Repeater {
                model: [
                    { label: qsTr("Account"), icon: "person" },
                    { label: qsTr("Appearance"), icon: "settings" },
                    { label: qsTr("History Reporting"), icon: "clock" },
                    { label: qsTr("Audio cache"), icon: "note" },
                    { label: qsTr("About"), icon: "album" }
                ]
                delegate: Rectangle {
                    id: sideItem
                    required property var modelData
                    required property int index
                    readonly property bool active: settingsPage.currentSection === sideItem.index

                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: Theme.radiusMd
                    color: sideItem.active ? Theme.primaryContainer : (sideArea.containsMouse ? Theme.surfaceContainer : "transparent")

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingMd
                        anchors.rightMargin: Theme.spacingMd
                        spacing: Theme.spacingSm

                        Icon {
                            name: sideItem.modelData.icon
                            size: 18
                            color: sideItem.active ? Theme.primary : Theme.onSurfaceVariant
                        }
                        Text {
                            text: sideItem.modelData.label
                            color: sideItem.active ? Theme.onPrimaryContainer : Theme.onSurfaceVariant
                            font: Theme.fontBodyMedium
                        }
                    }

                    MouseArea {
                        id: sideArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: settingsPage.currentSection = sideItem.index
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        // --- Content ---------------------------------------------------------
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth

            StackLayout {
                width: settingsPage.width - Theme.spacingLg * 2 - 240 - Theme.spacingLg
                currentIndex: settingsPage.currentSection

                // Account
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm

                    Text { text: qsTr("Account"); color: Theme.onSurfaceVariant; font: Theme.fontLabelSmall }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72
                        radius: Theme.radiusLg
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

                // Appearance
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
                                radius: Theme.radiusFull
                                color: themeChip.active ? Theme.primaryContainer : Theme.surfaceContainer
                                border.color: themeChip.active ? Theme.primary : Theme.outline
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

                // History Reporting
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm

                    Text { text: qsTr("History Reporting"); color: Theme.onSurfaceVariant; font: Theme.fontLabelSmall }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72
                        radius: Theme.radiusLg
                        color: Theme.surfaceContainer

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingMd
                            spacing: Theme.spacingSm

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    text: qsTr("Report plays to YouTube Music")
                                    color: Theme.onSurface
                                    font: Theme.fontTitleMedium
                                }
                                Text {
                                    text: qsTr("Include SonicTune plays in your YTM Recap and listening history")
                                    color: Theme.onSurfaceVariant
                                    font: Theme.fontBodySmall
                                }
                            }

                            Switch {
                                checked: settingsPage.reportHistory
                                Material.accent: Theme.primary
                                onToggled: {
                                    settingsPage.reportHistory = checked
                                    Daemon.setReportHistory(checked)
                                }
                            }
                        }
                    }
                }

                // Audio cache
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm

                    Text { text: qsTr("Audio cache"); color: Theme.onSurfaceVariant; font: Theme.fontLabelSmall }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        radius: Theme.radiusLg
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

                // About
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Theme.spacingXl
                    spacing: Theme.spacingSm

                    Text { text: qsTr("About"); color: Theme.onSurfaceVariant; font: Theme.fontLabelSmall }
                    Text {
                        text: qsTr("SonicTune — a native YouTube Music client for Linux, built with PySide6 and mpv.")
                        color: Theme.onSurfaceVariant
                        font: Theme.fontBodySmall
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    Text {
                        text: qsTr("Version %1").arg(typeof AppVersion !== "undefined" ? AppVersion : "0.1.0")
                        color: Theme.onSurfaceVariant
                        font: Theme.fontBodySmall
                    }
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
