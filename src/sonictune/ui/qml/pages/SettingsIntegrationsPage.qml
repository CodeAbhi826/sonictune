// pages/SettingsIntegrationsPage.qml — account + integrations sub-page.

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Dialogs
import QtQuick.Layouts
import "../theme"
import "../components"
import "../router"

Item {
    id: page

    property string pageTitle: qsTr("Integrations")
    property bool authenticated: false
    property bool reportHistory: true

    Connections {
        target: Daemon
        function onAuthChanged(a) { page.authenticated = a }
        function onImportCookiesCompleted(success) {
            toast.show(success ? qsTr("Cookies imported — signed in") : qsTr("Couldn't import cookies"))
        }
        function onImportCookiesError(err) { toast.show(qsTr("Import failed: %1").arg(err)) }
    }

    Component.onCompleted: {
        page.authenticated = Daemon.isAuthenticated()
        page.reportHistory = Daemon.reportHistory()
    }

    OAuthDialog {
        id: oauthDialog
        onOauthComplete: page.authenticated = true
    }

    FileDialog {
        id: cookieDialog
        title: qsTr("Select exported cookies.txt")
        nameFilters: [qsTr("Text files (*.txt)"), qsTr("All files (*)")]
        onAccepted: Daemon.importCookies(selectedFile.toString().replace("file://", ""))
    }

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

                        Icon {
                            name: page.authenticated ? "check" : "warning"
                            size: 16
                            color: page.authenticated ? Theme.success : Theme.fgSurfaceVariant
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                text: page.authenticated ? qsTr("Signed in to YouTube Music") : qsTr("Not signed in")
                                color: Theme.fgSurface
                                font: Theme.fontTitleMedium
                            }
                            Text {
                                text: page.authenticated
                                    ? qsTr("Library, recommendations, and history are available")
                                    : qsTr("Sign in for your library and personalized home feed")
                                color: Theme.fgSurfaceVariant
                                font: Theme.fontBodySmall
                            }
                        }

                        STButton {
                            text: page.authenticated ? qsTr("Sign out") : qsTr("Sign in")
                            variant: page.authenticated ? "outlined" : "filled"
                            onClicked: {
                                if (page.authenticated) {
                                    Daemon.logout()
                                    page.authenticated = false
                                } else {
                                    oauthDialog.open()
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space3
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Prefer browser cookies instead? Export them with a browser extension, then import the file.")
                        color: Theme.fgSurfaceVariant
                        font: Theme.fontBodySmall
                        wrapMode: Text.Wrap
                    }
                    STButton {
                        text: qsTr("Import cookies")
                        iconName: "download"
                        variant: "outlined"
                        onClicked: cookieDialog.open()
                    }
                }

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
                            Text {
                                text: qsTr("Report plays to YouTube Music")
                                color: Theme.fgSurface
                                font: Theme.fontTitleMedium
                            }
                            Text {
                                text: qsTr("Include SonicTune plays in your YTM Recap and listening history")
                                color: Theme.fgSurfaceVariant
                                font: Theme.fontBodySmall
                            }
                        }

                        Switch {
                            checked: page.reportHistory
                            Material.accent: Theme.primary
                            onToggled: {
                                page.reportHistory = checked
                                Daemon.setReportHistory(checked)
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: Theme.space4 }
            }
        }
    }

    ErrorToast { id: toast }
}
