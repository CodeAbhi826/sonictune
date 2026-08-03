// pages/HomePage.qml — ArchiveTune-inspired home feed.
// "SonicTune" header, a row of mood chips, then horizontally scrolling
// sections of AlbumCards fed by Daemon.getHome().

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"

Item {
    id: homePage

    property var sections: []
    property bool loading: true
    property bool loadError: false

    readonly property var moods: [
        { label: qsTr("Feel good") },
        { label: qsTr("Sad") },
        { label: qsTr("Energize") },
        { label: qsTr("Relax") },
        { label: qsTr("Romance") },
        { label: qsTr("Focus") }
    ]

    Connections {
        target: Daemon
        function onHomeReceived(s) {
            homePage.sections = s || []
            homePage.loading = false
            homePage.loadError = false
        }
        function onHomeError(err) {
            homePage.loading = false
            homePage.loadError = true
        }
        function onConnectionChanged(connected) {
            if (connected) homePage.reload()
        }
    }

    function reload() {
        homePage.loading = true
        homePage.loadError = false
        Daemon.getHome()
    }

    Component.onCompleted: {
        if (Daemon.isConnected()) homePage.reload()
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        visible: !homePage.loading && !homePage.loadError && homePage.sections.length > 0

        ColumnLayout {
            width: homePage.width
            spacing: Theme.spacingLg

            // --- Header ---------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Theme.spacingLg
                Layout.bottomMargin: 0

                Text { text: qsTr("SonicTune"); color: Theme.onSurface; font: Theme.fontHeadline }
                Item { Layout.fillWidth: true }
                Item {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Icon { anchors.centerIn: parent; name: "sync"; size: 16; color: Theme.onSurfaceVariant }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: homePage.reload() }
                }
            }

            // --- Mood chips ------------------------------------------------
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingLg
                Layout.rightMargin: Theme.spacingLg
                spacing: Theme.spacingSm

                Repeater {
                    model: homePage.moods
                    delegate: Rectangle {
                        id: moodChip
                        required property var modelData
                        height: 36
                        width: moodLabel.implicitWidth + Theme.spacingLg
                        radius: Theme.radiusFull
                        color: moodArea.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceElevated
                        border.width: 1
                        border.color: Theme.outline

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                        Text {
                            id: moodLabel
                            anchors.centerIn: parent
                            text: moodChip.modelData.label
                            color: Theme.onSurfaceVariant
                            font: Theme.fontLabelLarge
                        }

                        MouseArea {
                            id: moodArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Daemon.search(moodChip.modelData.label, "songs", 20)
                            }
                        }
                    }
                }
            }

            // --- Sections of cards ------------------------------------------
            Repeater {
                model: homePage.sections

                delegate: ColumnLayout {
                    id: sectionDelegate
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.spacingLg
                    spacing: Theme.spacingSm
                    visible: (sectionDelegate.modelData.items || []).length > 0

                    Text {
                        text: sectionDelegate.modelData.title || ""
                        color: Theme.onSurface
                        font: Theme.fontTitleLarge
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 236
                        contentHeight: 236
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                        RowLayout {
                            height: 236
                            spacing: Theme.spacingMd

                            Repeater {
                                model: sectionDelegate.modelData.items || []

                                delegate: AlbumCard {
                                    id: itemCard
                                    required property var modelData

                                    title: itemCard.modelData.title || qsTr("Unknown")
                                    subtitle: itemCard.modelData.subtitle || ""
                                    thumbnailUrl: itemCard.modelData.thumbnail_url || ""
                                    onClicked: {
                                        if (itemCard.modelData.video_id) {
                                            Daemon.playTrack(itemCard.modelData.video_id)
                                        } else if (itemCard.modelData.browse_id) {
                                            Daemon.search(itemCard.title, "songs", 20)
                                        }
                                    }
                                }
                            }

                            Item { Layout.preferredWidth: Theme.spacingLg }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: Theme.spacingXl }
        }
    }

    LoadingOverlay {
        id: overlay
        opacity: homePage.loading ? 1 : 0
        message: qsTr("Loading your home feed…")
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: !homePage.loading && (homePage.loadError || homePage.sections.length === 0)
        spacing: Theme.spacingMd
        width: 320

        Icon { Layout.alignment: Qt.AlignHCenter; name: "home"; size: 32; color: Theme.onSurfaceVariant }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: homePage.loadError
                ? qsTr("Couldn't load your home feed")
                : qsTr("Your home feed is empty")
            color: Theme.onSurface
            font: Theme.fontTitleMedium
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: homePage.loadError
                ? qsTr("Try again, or head to Search.")
                : qsTr("Sign in from Settings for personalized recommendations, or head to Search.")
            color: Theme.onSurfaceVariant
            font: Theme.fontBodySmall
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
        STButton {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Try again")
            variant: "tonal"
            onClicked: homePage.reload()
        }
    }
}
