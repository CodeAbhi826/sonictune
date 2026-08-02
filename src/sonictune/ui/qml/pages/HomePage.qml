// pages/HomePage.qml — personalized home feed.
//
// BUGFIX: this page used to never call anything — Daemon.getHome() didn't
// even exist as a callable Slot, so `sections` was always [] and the page
// sat on its "loading" placeholder forever. Daemon.getHome()/homeReceived
// now exist (see dbus_client.py) and are wired up below.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import "../theme"
import "../components"

Item {
    id: homePage

    property var sections: []
    property bool loading: true
    property bool loadError: false

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
        if (Daemon.connected) homePage.reload()
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        visible: !homePage.loading && !homePage.loadError && homePage.sections.length > 0

        ColumnLayout {
            width: homePage.width
            spacing: Theme.spacingLg

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Theme.spacingLg
                Layout.bottomMargin: 0

                Text { text: qsTr("Home"); color: Theme.onSurface; font: Theme.fontHeadlineMedium }
                Item { Layout.fillWidth: true }
                Item {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Icon { anchors.centerIn: parent; name: "sync"; size: 16; color: Theme.onSurfaceVariant }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: homePage.reload() }
                }
            }

            Repeater {
                model: homePage.sections

                delegate: ColumnLayout {
                    id: sectionDelegate
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.spacingLg
                    spacing: Theme.spacingSm
                    visible: (sectionDelegate.modelData.contents || []).length > 0

                    Text {
                        text: sectionDelegate.modelData.title || ""
                        color: Theme.onSurface
                        font: Theme.fontTitleLarge
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 232
                        contentHeight: 224
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                        RowLayout {
                            height: 224
                            spacing: Theme.spacingMd

                            Repeater {
                                model: sectionDelegate.modelData.contents || []

                                delegate: AlbumCard {
                                    id: itemCard
                                    required property var modelData

                                    title: itemCard.modelData.title || itemCard.modelData.name || qsTr("Unknown")
                                    subtitle: (itemCard.modelData.artists && itemCard.modelData.artists.length > 0)
                                        ? itemCard.modelData.artists.map(function(a) { return a.name }).join(", ")
                                        : (itemCard.modelData.subtitle || itemCard.modelData.album || "")
                                    thumbnailUrl: (itemCard.modelData.thumbnails && itemCard.modelData.thumbnails.length > 0)
                                        ? itemCard.modelData.thumbnails[itemCard.modelData.thumbnails.length - 1].url
                                        : ""
                                    onClicked: {
                                        if (itemCard.modelData.videoId) {
                                            Daemon.playTrack(itemCard.modelData.videoId)
                                        } else {
                                            var q = itemCard.modelData.title || itemCard.modelData.name || ""
                                            if (q) Daemon.search(q, "", 20)
                                        }
                                    }
                                }
                            }

                            Item { Layout.preferredWidth: Theme.spacingLg }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: Theme.spacingLg }
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
                : qsTr("Nothing to show here yet")
            color: Theme.onSurface
            font: Theme.fontTitleMedium
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: homePage.loadError
                ? qsTr("Check that the daemon is running, or try again.")
                : qsTr("Sign in from Settings for personalized recommendations, or head to Search.")
            color: Theme.onSurfaceVariant
            font: Theme.fontBodySmall
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
        Button {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Try again")
            flat: true
            onClicked: homePage.reload()
        }
    }
}
