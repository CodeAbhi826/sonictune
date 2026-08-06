// pages/SettingsPlayerPage.qml — audio + playback sub-page.

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "../theme"
import "../components"
import "../router"

Item {
    id: page

    property string pageTitle: qsTr("Player")
    property string audioQuality: "standard"
    property int currentItag: 0
    property real crossfadeValue: 0
    property real speedValue: 1.0

    Connections {
        target: Daemon
        function onAudioQualityChanged(q) { page.audioQuality = q }
        function onCurrentAudioItagChanged(itag) { page.currentItag = itag }
    }

    Component.onCompleted: {
        page.audioQuality = Daemon.audioQuality()
        page.currentItag = Daemon.currentAudioItag()
        page.crossfadeValue = Daemon.crossfade()
        page.speedValue = Daemon.speed()
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

                Text { text: qsTr("Audio quality"); color: Theme.fgSurface; font: Theme.fontTitleMedium }
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
                            readonly property bool active: page.audioQuality === qualityPill.modelData.key

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
                                color: qualityPill.active ? Theme.fgPrimaryContainer : Theme.fgSurface
                                font: Theme.fontLabelLarge
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    page.audioQuality = qualityPill.modelData.key
                                    Daemon.setAudioQuality(qualityPill.modelData.key)
                                }
                            }
                        }
                    }
                }
                Text {
                    text: page.qualityLabel()
                    color: Theme.fgSurfaceVariant
                    font: Theme.fontBodySmall
                    visible: page.audioQuality === "high"
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

                        Icon { name: "speaker"; size: 18; color: Theme.fgSurfaceVariant }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text { text: qsTr("Output device"); color: Theme.fgSurface; font: Theme.fontBodyMedium }
                            Text { text: qsTr("Coming soon"); color: Theme.fgSurfaceVariant; font: Theme.fontBodySmall }
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
                        anchors.margins: Theme.space4
                        spacing: Theme.space3

                        Icon { name: "memory"; size: 18; color: Theme.fgSurfaceVariant }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text { text: qsTr("Hardware acceleration"); color: Theme.fgSurface; font: Theme.fontBodyMedium }
                            Text { text: qsTr("Auto (VAAPI/NVDEC)"); color: Theme.fgSurfaceVariant; font: Theme.fontBodySmall }
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
                        anchors.margins: Theme.space4
                        spacing: Theme.space3

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text { text: qsTr("Audio normalization"); color: Theme.fgSurface; font: Theme.fontBodyMedium }
                            Text { text: qsTr("Loudness normalization (I=-16 LUFS)"); color: Theme.fgSurfaceVariant; font: Theme.fontBodySmall }
                        }

                        Switch {
                            checked: true
                            enabled: false
                            Material.accent: Theme.primary
                        }
                    }
                }

                Item { Layout.preferredHeight: Theme.space2 }

                Text { text: qsTr("Playback"); color: Theme.fgSurface; font: Theme.fontTitleMedium }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: qsTr("Crossfade"); color: Theme.fgSurface; font: Theme.fontBodyMedium }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: qsTr("%n s", "", Math.round(page.crossfadeValue))
                        color: Theme.fgSurfaceVariant
                        font: Theme.fontMono
                    }
                }
                STSlider {
                    Layout.fillWidth: true
                    from: 0
                    to: 12
                    value: page.crossfadeValue
                    onMoved: {
                        page.crossfadeValue = value
                        Daemon.setCrossfade(Math.round(value))
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.space2
                    Text { text: qsTr("Playback speed"); color: Theme.fgSurface; font: Theme.fontBodyMedium }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: page.speedValue.toFixed(2) + "x"
                        color: Theme.fgSurfaceVariant
                        font: Theme.fontMono
                    }
                }
                STSlider {
                    Layout.fillWidth: true
                    from: 0.5
                    to: 2.0
                    stepSize: 0.05
                    value: page.speedValue
                    onMoved: {
                        page.speedValue = value
                        Daemon.setSpeed(value)
                    }
                }

                Text {
                    Layout.topMargin: Theme.space2
                    text: qsTr("Sleep timer")
                    color: Theme.fgSurface
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
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Start a sleep timer from the Now Playing page.")
                    color: Theme.fgSurfaceVariant
                    font: Theme.fontBodySmall
                    wrapMode: Text.Wrap
                }

                Item { Layout.preferredHeight: Theme.space4 }
            }
        }
    }

    function qualityLabel() {
        if (page.currentItag === 141) return "256kbps AAC (Premium)"
        if (page.currentItag === 774) return "256kbps Opus"
        if (page.currentItag === 251) return "128kbps Opus"
        return qsTr("Auto")
    }
}
