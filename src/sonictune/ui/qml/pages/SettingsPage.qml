// pages/SettingsPage.qml — collapsible, sectioned settings (Material 3).
// Sections: Audio, Playback, Account, Performance, About. Only one section
// is expanded at a time (enforced via SettingsSection.expandRequested).

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Dialogs
import QtQuick.Layouts
import "../theme"
import "../components"

Item {
    id: settingsPage

    property bool authenticated: false
    property real audioCacheBytes: 0
    property bool reportHistory: true
    property int currentSection: 0

    property string audioQuality: "standard"
    property int currentItag: 0
    property real crossfadeValue: 0
    property real speedValue: 1.0
    property string sleepTimerSelection: "0"

    Connections {
        target: Daemon
        function onAuthChanged(a) { settingsPage.authenticated = a }
        function onAudioCacheSizeReceived(b) { settingsPage.audioCacheBytes = b }
        function onAudioCacheCleared() {
            settingsPage.audioCacheBytes = 0
            toast.show(qsTr("Audio cache cleared"))
        }
        function onImportCookiesCompleted(success) {
            toast.show(success ? qsTr("Cookies imported — signed in") : qsTr("Couldn't import cookies"))
        }
        function onImportCookiesError(err) { toast.show(qsTr("Import failed: %1").arg(err)) }
        function onAudioQualityChanged(q) { settingsPage.audioQuality = q }
        function onCurrentAudioItagChanged(itag) { settingsPage.currentItag = itag }
    }

    Component.onCompleted: {
        settingsPage.authenticated = Daemon.isAuthenticated()
        settingsPage.reportHistory = Daemon.reportHistory()
        settingsPage.audioQuality = Daemon.audioQuality()
        settingsPage.currentItag = Daemon.currentAudioItag()
        settingsPage.crossfadeValue = Daemon.crossfade()
        settingsPage.speedValue = Daemon.speed()
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
            Text { text: qsTr("Settings"); color: Theme.onSurface; font: Theme.fontHeadlineMedium }
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

                 // ---- Audio -------------------------------------------------
                SettingsSection {
                    id: audioSection
                    title: qsTr("Audio")
                    icon: "equalizer"
                    onExpandRequested: settingsPage.collapseOthers(audioSection)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space3

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: qsTr("Audio quality")
                                color: Theme.onSurface
                                font: Theme.fontTitleMedium
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: settingsPage.qualityLabel()
                                color: Theme.onSurfaceVariant
                                font: Theme.fontBodySmall
                                visible: settingsPage.audioQuality === "high"
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.space3

                            Repeater {
                                model: [
                                    { key: "low", label: qsTr("Low") },
                                    { key: "standard", label: qsTr("Standard") },
                                    { key: "high", label: qsTr("High") }
                                ]
                                delegate: Rectangle {
                                    id: qualityPill
                                    required property var modelData
                                    readonly property bool active: settingsPage.audioQuality === qualityPill.modelData.key

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    radius: Theme.radiusFull
                                    color: qualityPill.active ? Theme.primaryContainer : Theme.surfaceContainer
                                    border.width: 1
                                    border.color: qualityPill.active ? Theme.primary : Theme.outline
                                    Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.durFast } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: qualityPill.modelData.label
                                        color: qualityPill.active ? Theme.onPrimaryContainer : Theme.onSurface
                                        font: Theme.fontLabelLarge
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            settingsPage.audioQuality = qualityPill.modelData.key
                                            Daemon.setAudioQuality(qualityPill.modelData.key)
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            radius: Theme.radiusMd
                            color: Theme.surfaceContainer

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.space4
                                anchors.rightMargin: Theme.space4
                                spacing: Theme.space3

                                Icon { name: "speaker"; size: 18; color: Theme.onSurfaceVariant }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text { text: qsTr("Output device"); color: Theme.onSurface; font: Theme.fontBodyMedium }
                                    Text { text: qsTr("Coming soon"); color: Theme.onSurfaceVariant; font: Theme.fontBodySmall }
                                }
                            }
                        }

                        // Hardware acceleration
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            radius: Theme.radiusMd
                            color: Theme.surfaceContainer

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.space4
                                anchors.rightMargin: Theme.space4
                                spacing: Theme.space3

                                Icon { name: "memory"; size: 18; color: Theme.onSurfaceVariant }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text { text: qsTr("Hardware acceleration"); color: Theme.onSurface; font: Theme.fontBodyMedium }
                                    Text { text: qsTr("Auto (VAAPI/NVDEC)"); color: Theme.onSurfaceVariant; font: Theme.fontBodySmall }
                                }
                            }
                        }

                        // Audio normalization
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            radius: Theme.radiusMd
                            color: Theme.surfaceContainer

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.space4
                                anchors.rightMargin: Theme.space4
                                spacing: Theme.space3

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text { text: qsTr("Audio normalization"); color: Theme.onSurface; font: Theme.fontBodyMedium }
                                    Text { text: qsTr("Loudness normalization (I=-16 LUFS)"); color: Theme.onSurfaceVariant; font: Theme.fontBodySmall }
                                }

                                Switch {
                                    checked: true  // Always enabled for now
                                    enabled: false  // Disabled until configurable
                                    Material.accent: Theme.primary
                                }
                            }
                        }
                    }
                }

                // ---- Playback ------------------------------------------------
                SettingsSection {
                    id: playbackSection
                    title: qsTr("Playback")
                    icon: "play_circle"
                    onExpandRequested: settingsPage.collapseOthers(playbackSection)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space4

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTr("Crossfade"); color: Theme.onSurface; font: Theme.fontBodyMedium }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: qsTr("%n s", "", Math.round(settingsPage.crossfadeValue))
                                color: Theme.onSurfaceVariant
                                font: Theme.fontMono
                            }
                        }
                        STSlider {
                            Layout.fillWidth: true
                            from: 0
                            to: 12
                            value: settingsPage.crossfadeValue
                            onMoved: {
                                settingsPage.crossfadeValue = value
                                Daemon.setCrossfade(Math.round(value))
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Theme.space2
                            Text { text: qsTr("Playback speed"); color: Theme.onSurface; font: Theme.fontBodyMedium }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: settingsPage.speedValue.toFixed(2) + "x"
                                color: Theme.onSurfaceVariant
                                font: Theme.fontMono
                            }
                        }
                        STSlider {
                            Layout.fillWidth: true
                            from: 0.5
                            to: 2.0
                            stepSize: 0.05
                            value: settingsPage.speedValue
                            onMoved: {
                                settingsPage.speedValue = value
                                Daemon.setSpeed(value)
                            }
                        }

                        Text {
                            Layout.topMargin: Theme.space2
                            text: qsTr("Sleep timer")
                            color: Theme.onSurface
                            font: Theme.fontBodyMedium
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.space2

                            Repeater {
                                model: [
                                    { key: "0", label: qsTr("Off") },
                                    { key: "5", label: qsTr("5 min") },
                                    { key: "15", label: qsTr("15 min") },
                                    { key: "30", label: qsTr("30 min") },
                                    { key: "45", label: qsTr("45 min") },
                                    { key: "60", label: qsTr("60 min") }
                                ]
                                delegate: STButton {
                                    id: sleepPill
                                    required property var modelData
                                    text: sleepPill.modelData.label
                                    variant: "tonal"
                                    onClicked: settingsPage.sleepTimerSelection = sleepPill.modelData.key
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Start a sleep timer from the Now Playing page.")
                            color: Theme.onSurfaceVariant
                            font: Theme.fontBodySmall
                            wrapMode: Text.Wrap
                        }
                    }
                }

                // ---- Account --------------------------------------------------
                SettingsSection {
                    id: accountSection
                    title: qsTr("Account")
                    icon: "person"
                    onExpandRequested: settingsPage.collapseOthers(accountSection)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space3

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

                                STButton {
                                    text: settingsPage.authenticated ? qsTr("Sign out") : qsTr("Sign in")
                                    variant: settingsPage.authenticated ? "outlined" : "filled"
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
                            spacing: Theme.space3
                            Text {
                                Layout.fillWidth: true
                                text: qsTr("Prefer browser cookies instead? Export them with a browser extension, then import the file.")
                                color: Theme.onSurfaceVariant
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
                }

                // ---- Performance -----------------------------------------------
                SettingsSection {
                    id: performanceSection
                    title: qsTr("Performance")
                    icon: "memory"
                    onExpandRequested: settingsPage.collapseOthers(performanceSection)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space3

                        Repeater {
                            model: [
                                { key: "reducedMotion", label: qsTr("Reduced motion"), desc: qsTr("Disable animations and transitions") },
                                { key: "lowEndMode", label: qsTr("Low-end mode"), desc: qsTr("Disable shadows, limit heavy effects") },
                                { key: "disableShadows", label: qsTr("Disable shadows"), desc: qsTr("Drop all drop shadows") },
                                { key: "disableImageCache", label: qsTr("Disable image cache"), desc: qsTr("Don't cache artwork thumbnails") },
                                { key: "smoothScrolling", label: qsTr("Smooth scrolling"), desc: qsTr("Enable momentum on lists") }
                            ]
                            delegate: Rectangle {
                                id: perfRow
                                required property var modelData
                                Layout.fillWidth: true
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
                                        Text {
                                            text: perfRow.modelData.label
                                            color: Theme.onSurface
                                            font: Theme.fontBodyMedium
                                        }
                                        Text {
                                            text: perfRow.modelData.desc
                                            color: Theme.onSurfaceVariant
                                            font: Theme.fontBodySmall
                                        }
                                    }

                                    Switch {
                                        checked: {
                                            var k = perfRow.modelData.key
                                            return k === "reducedMotion" ? Theme.reducedMotion
                                                : k === "lowEndMode" ? Theme.lowEndMode
                                                : k === "disableShadows" ? Theme.disableShadows
                                                : k === "disableImageCache" ? Theme.disableImageCache
                                                : Theme.smoothScrolling
                                        }
                                        Material.accent: Theme.primary
                                        onToggled: {
                                            var k = perfRow.modelData.key
                                            if (k === "reducedMotion") Theme.reducedMotion = checked
                                            else if (k === "lowEndMode") Theme.lowEndMode = checked
                                            else if (k === "disableShadows") Theme.disableShadows = checked
                                            else if (k === "disableImageCache") Theme.disableImageCache = checked
                                            else Theme.smoothScrolling = checked
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Theme.space2
                            Text { text: qsTr("Image source size"); color: Theme.onSurface; font: Theme.fontBodyMedium }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: String(Theme.imageSourceSize)
                                color: Theme.onSurfaceVariant
                                font: Theme.fontMono
                            }
                        }
                        STSlider {
                            Layout.fillWidth: true
                            from: 128
                            to: 1024
                            stepSize: 32
                            value: Theme.imageSourceSize
                            onMoved: Theme.imageSourceSize = Math.round(value)
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Theme.space2
                            Text { text: qsTr("List cache buffer"); color: Theme.onSurface; font: Theme.fontBodyMedium }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: String(Theme.listCacheBuffer)
                                color: Theme.onSurfaceVariant
                                font: Theme.fontMono
                            }
                        }
                        STSlider {
                            Layout.fillWidth: true
                            from: 0
                            to: 500
                            stepSize: 10
                            value: Theme.listCacheBuffer
                            onMoved: Theme.listCacheBuffer = Math.round(value)
                        }
                    }
                }

                // ---- About -------------------------------------------------------
                SettingsSection {
                    id: aboutSection
                    title: qsTr("About")
                    icon: "info"
                    onExpandRequested: settingsPage.collapseOthers(aboutSection)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space3

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            radius: Theme.radiusLg
                            color: Theme.surfaceContainer

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.space4
                                spacing: Theme.space3

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text { text: qsTr("Downloaded audio cache"); color: Theme.onSurface; font: Theme.fontTitleMedium }
                                    Text {
                                        text: settingsPage.formatBytes(settingsPage.audioCacheBytes)
                                        color: Theme.onSurfaceVariant
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
                            text: qsTr("SonicTune — a native YouTube Music client for Linux, built with PySide6 and mpv.")
                            color: Theme.onSurfaceVariant
                            font: Theme.fontBodySmall
                            wrapMode: Text.Wrap
                        }
                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Version %1").arg(typeof AppVersion !== "undefined" ? AppVersion : "0.1.0")
                            color: Theme.onSurfaceVariant
                            font: Theme.fontBodySmall
                        }
                    }
                }

                Item { Layout.preferredHeight: Theme.space2 }
            }
        }
    }

    ErrorToast { id: toast }

    function collapseOthers(keep) {
        var sections = [audioSection, playbackSection, accountSection, performanceSection, aboutSection]
        for (var i = 0; i < sections.length; i++) {
            if (sections[i] && sections[i] !== keep) sections[i].expanded = false
        }
    }

    function qualityLabel() {
        if (settingsPage.currentItag === 141) return "256kbps AAC (Premium)"
        if (settingsPage.currentItag === 774) return "256kbps Opus"
        if (settingsPage.currentItag === 251) return "128kbps Opus"
        return qsTr("Auto")
    }

    function formatBytes(bytes) {
        if (!bytes || bytes <= 0) return qsTr("0 MB")
        var mb = bytes / (1024 * 1024)
        if (mb < 1024) return mb.toFixed(1) + " MB"
        return (mb / 1024).toFixed(2) + " GB"
    }
}
