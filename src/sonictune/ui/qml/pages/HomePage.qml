// pages/HomePage.qml — home feed with a greeting, mood chips, and
// horizontally scrolling sections of AlbumCards fed by Daemon.getHome().

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"
import "../router"

Item {
    id: homePage

    property var sections: []
    property bool loading: true
    property bool loadError: false
    property int selectedMood: -1

    signal openSearch(string query)

    readonly property var moods: [
        { label: qsTr("Focus") },
        { label: qsTr("Energy") },
        { label: qsTr("Chill") },
        { label: qsTr("Nostalgia") }
    ]

    readonly property string greeting: {
        var h = new Date().getHours()
        if (h < 5) return qsTr("Good night")
        if (h < 12) return qsTr("Good morning")
        if (h < 18) return qsTr("Good afternoon")
        return qsTr("Good evening")
    }

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

        // --- Header --------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: homePage.greeting
                    color: Theme.fgSurface
                    font: Theme.fontHeadlineMedium
                }
                Text {
                    text: qsTr("Welcome back to SonicTune")
                    color: Theme.fgSurfaceVariant
                    font: Theme.fontBodyMedium
                }
            }

            IconButton {
                icon: "sync"
                diameter: 36
                iconSize: 18
                onClicked: homePage.reload()
            }
        }

        // --- Mood chips ------------------------------------------------------
        Flow {
            Layout.fillWidth: true
            spacing: Theme.space2

            Repeater {
                model: homePage.moods
                delegate: Rectangle {
                    id: moodChip
                    required property var modelData
                    required property int index

                    readonly property bool active: homePage.selectedMood === moodChip.index

                    Layout.preferredHeight: 36
                    Layout.preferredWidth: moodLabel.implicitWidth + Theme.space6
                    radius: Theme.radiusFull
                    color: moodChip.active ? Theme.primaryContainer : Theme.surfaceContainer
                    border.width: 1
                    border.color: moodChip.active ? Theme.primary : Theme.outline
                    Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.durFast } }

                    Text {
                        id: moodLabel
                        anchors.centerIn: parent
                        text: moodChip.modelData.label
                        color: moodChip.active ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
                        font: Theme.fontLabelLarge
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: homePage.selectedMood = (homePage.selectedMood === moodChip.index) ? -1 : moodChip.index
                    }
                }
            }
        }

        // --- Sections of cards --------------------------------------------------
        Flickable {
            id: homeScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: homeSectionsColumn.implicitHeight
            clip: true
            visible: !homePage.loading && !homePage.loadError && homePage.sections.length > 0

            property bool pullReady: homeScroll.contentY <= -Theme.space6 * 8

            onDragEnded: {
                if (homeScroll.pullReady) homePage.reload()
            }

            ColumnLayout {
                id: homeSectionsColumn
                width: homeScroll.width
                spacing: Theme.space6

                // Pull-to-refresh indicator
                Item {
                    id: pullIndicator
                    Layout.fillWidth: true
                    Layout.preferredHeight: (homeScroll.contentY < 0 || homePage.loading)
                        ? Theme.space6 * 4 : 0
                    Behavior on Layout.preferredHeight {
                        enabled: !Theme.reducedMotion
                        NumberAnimation { duration: Theme.durFast }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: homeScroll.pullReady
                            ? qsTr("Release to refresh")
                            : qsTr("Pull to refresh")
                        color: Theme.fgSurfaceVariant
                        font: Theme.fontLabelMedium
                        opacity: 0.7
                    }
                }

                Repeater {
                    model: homePage.sections

                    delegate: ColumnLayout {
                        id: sectionDelegate
                        required property var modelData

                        readonly property bool isHeader: sectionDelegate.modelData.type === "header"
                        readonly property var items: sectionDelegate.modelData.items || []

                        Layout.fillWidth: true
                        spacing: Theme.space3
                        visible: sectionDelegate.isHeader || sectionDelegate.items.length > 0

                        Text {
                            Layout.fillWidth: true
                            text: sectionDelegate.modelData.title || ""
                            color: Theme.fgSurface
                            font: Theme.fontTitleLarge
                            elide: Text.ElideRight
                            visible: text.length > 0
                        }

                        // A "row" section shows horizontally scrolling cards.
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 236
                            clip: true
                            visible: !sectionDelegate.isHeader && sectionDelegate.items.length > 0
                            ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                            RowLayout {
                                height: 236
                                spacing: Theme.space4

                                Repeater {
                                    model: sectionDelegate.items

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
                                                Router.pushPage("AlbumDetailPage.qml", {
                                                    albumId: itemCard.modelData.browse_id,
                                                    albumTitle: itemCard.modelData.title || ""
                                                })
                                            }
                                        }
                                    }
                                }

                                Item { Layout.preferredWidth: Theme.space4 }
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: Theme.space6 }
            }
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
        spacing: Theme.space4
        width: 320

        Icon { Layout.alignment: Qt.AlignHCenter; name: "music_off"; size: 32; color: Theme.fgSurfaceVariant }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: homePage.loadError
                ? qsTr("Couldn't load your home feed")
                : qsTr("Your home feed is empty")
            color: Theme.fgSurface
            font: Theme.fontTitleMedium
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: homePage.loadError
                ? qsTr("Try again, or head to Search.")
                : qsTr("Sign in from Settings for personalized recommendations, or head to Search.")
            color: Theme.fgSurfaceVariant
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
