// components/OAuthDialog.qml — YouTube Music sign-in via device OAuth
// (Material 3 Dark). Copies the verification URL via the Clipboard context
// property and opens it in the system browser with Qt.openUrlExternally.
//
// Note on the font-group pitfall from the project's own bug history: never
// bind the `font` group property (`font: Theme.fontXxx`) and then also set
// an individual `font.*` sub-property on the SAME Text element — QML
// treats that as the group property being assigned twice and throws
// "Property has already been assigned a value" at load time. Every Text
// below either uses the group form OR individual font.* properties, never
// both on one element.

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "../theme"

Dialog {
    id: dialog
    modal: true
    anchors.centerIn: parent
    width: 460
    padding: 0
    closePolicy: Popup.CloseOnEscape

    signal oauthComplete()

    property string clientId: ""
    property string clientSecret: ""
    property string userCode: ""
    property string verificationUrl: ""
    property bool polling: false
    property string statusMessage: ""
    property bool isError: false

    background: Rectangle {
        color: Theme.surfaceContainerHigh
        radius: Theme.radiusLg
        border.color: Theme.outline
        border.width: 1
    }

    Timer {
        id: pollTimer
        interval: 3000
        repeat: true
        onTriggered: Daemon.pollOAuth()
    }

    Connections {
        target: Daemon
        function onStartOAuthCompleted(result) {
            dialog.userCode = result.user_code || ""
            dialog.verificationUrl = result.verification_url || ""
            dialog.polling = true
            dialog.statusMessage = qsTr("Waiting for you to approve on YouTube…")
            dialog.isError = false
            pollTimer.start()
        }
        function onStartOAuthError(err) {
            dialog.statusMessage = qsTr("Couldn't start sign-in: %1").arg(err)
            dialog.isError = true
        }
        function onPollOAuthCompleted(success) {
            if (success) {
                pollTimer.stop()
                dialog.polling = false
                dialog.statusMessage = qsTr("Signed in!")
                dialog.isError = false
                dialog.oauthComplete()
                closeTimer.start()
            }
        }
        function onPollOAuthError(err) {
            pollTimer.stop()
            dialog.polling = false
            dialog.statusMessage = qsTr("Sign-in failed: %1").arg(err)
            dialog.isError = true
        }
    }

    Timer { id: closeTimer; interval: 900; onTriggered: dialog.close() }

    onClosed: {
        pollTimer.stop()
        polling = false
        userCode = ""
        statusMessage = ""
    }

    contentItem: ColumnLayout {
        spacing: 0

        // --- Header --------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.space6
            Layout.bottomMargin: Theme.space2

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: qsTr("Sign in to YouTube Music"); color: Theme.fgSurface; font: Theme.fontTitleLarge }
                Text { text: qsTr("Uses YouTube's TV device sign-in flow"); color: Theme.fgSurfaceVariant; font: Theme.fontBodySmall }
            }

            Item {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                Icon { anchors.centerIn: parent; name: "close"; size: 14; color: Theme.fgSurfaceVariant }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dialog.close() }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.outline }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.space6
            spacing: Theme.space4

            // --- Step 1: credentials, hidden once we have a user code ------
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space2
                visible: !dialog.userCode

                Text {
                    Layout.fillWidth: true
                    text: qsTr("You'll need a free YouTube Data API OAuth client (client ID + secret) from Google Cloud Console — the same one-time setup any YTMusic OAuth tool needs.")
                    color: Theme.fgSurfaceVariant
                    font: Theme.fontBodySmall
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space1
                    Icon { name: "external"; size: 13; color: Theme.primary }
                    Text {
                        text: qsTr("console.cloud.google.com → create OAuth client (TVs and Limited Input devices)")
                        color: Theme.primary
                        font: Theme.fontBodySmall
                    }
                }

                Label { text: qsTr("Client ID"); color: Theme.fgSurfaceVariant; font: Theme.fontLabelSmall }
                TextField {
                    id: clientIdField
                    Layout.fillWidth: true
                    placeholderText: qsTr("xxxxxxxx.apps.googleusercontent.com")
                    color: Theme.fgSurface
                    Material.accent: Theme.primary
                }

                Label { text: qsTr("Client secret"); color: Theme.fgSurfaceVariant; font: Theme.fontLabelSmall }
                TextField {
                    id: clientSecretField
                    Layout.fillWidth: true
                    placeholderText: qsTr("GOCSPX-…")
                    echoMode: TextInput.Password
                    color: Theme.fgSurface
                    Material.accent: Theme.primary
                }

                STButton {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Theme.space1
                    variant: "filled"
                    text: qsTr("Continue")
                    enabled: clientIdField.text.length > 0 && clientSecretField.text.length > 0
                    onClicked: {
                        dialog.isError = false
                        dialog.statusMessage = qsTr("Starting sign-in…")
                        Daemon.startOAuth(clientIdField.text, clientSecretField.text)
                    }
                }
            }

            // --- Step 2: device code ----------------------------------------
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space2
                visible: dialog.userCode !== ""

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Go to %1 and enter this code:").arg(dialog.verificationUrl)
                    color: Theme.fgSurfaceVariant
                    font: Theme.fontBodyMedium
                    wrapMode: Text.Wrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    radius: Theme.radiusMd
                    color: Theme.surfaceContainer
                    border.color: Theme.outline
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: dialog.userCode
                        color: Theme.primary
                        font.family: Theme.fontFamilyMono
                        font.pixelSize: 26
                        font.weight: Font.Medium
                        font.letterSpacing: 4
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Theme.space3

                    STButton {
                        variant: "outlined"
                        iconName: "external"
                        text: qsTr("Open in browser")
                        onClicked: Qt.openUrlExternally(dialog.verificationUrl)
                    }

                    STButton {
                        variant: "text"
                        text: qsTr("Copy code")
                        onClicked: Clipboard.copy(dialog.userCode)
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Theme.space2
                    visible: dialog.polling
                    BusyIndicator { implicitWidth: 18; implicitHeight: 18; running: dialog.polling; Material.accent: Theme.primary }
                    Text { text: dialog.statusMessage; color: Theme.fgSurfaceVariant; font: Theme.fontBodySmall }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: dialog.isError && dialog.statusMessage
                text: dialog.statusMessage
                color: Theme.error
                font: Theme.fontBodySmall
                wrapMode: Text.Wrap
            }

            Item { Layout.preferredHeight: Theme.space2 }
        }
    }
}
