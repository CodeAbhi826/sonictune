// pages/ArtistDetailPage.qml — artist detail view pushed onto the navigation
// stack by Router. Fetches the artist's songs via Daemon.getArtistDetail()
// and renders a TrackList with a header.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"
import "../router"

Item {
    id: detailPage

    property string artistId: ""
    property string artistName: ""
    property var detail: ({})
    property var tracks: []
    property bool loading: false
    property bool loadFailed: false
    property string errorMessage: ""

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space4

        // --- Header -------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space2

            IconButton {
                iconName: "chevronLeft"
                iconSize: 18
                toolTip: qsTr("Back")
                onClicked: Router.popPage()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: detailPage.artistName || qsTr("Artist")
                    color: Theme.fgSurface
                    font: Theme.fontHeadlineSmall
                    elide: Text.ElideRight
                }
                Text {
                    text: detailPage.detail.subscriber_count || ""
                    color: Theme.fgSurfaceVariant
                    font: Theme.fontBodySmall
                    elide: Text.ElideRight
                }
            }

            STButton {
                text: qsTr("Play All")
                iconName: "play"
                variant: "tonal"
                enabled: detailPage.tracks.length > 0
                onClicked: Daemon.playTrack(detailPage.tracks[0].video_id || "")
            }
        }

        // --- Header artwork + top tracks ----------------------------------
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: detailPage.width
                spacing: Theme.space4

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.space4
                    Layout.rightMargin: Theme.space4
                    spacing: Theme.space4

                    Rectangle {
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 120
                        radius: 60
                        color: Theme.surfaceContainer
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: detailPage.detail.thumbnail_url
                                ? "image://art/" + encodeURIComponent(detailPage.detail.thumbnail_url)
                                : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: !detailPage.detail.thumbnail_url
                            name: "person"
                            size: 40
                            color: Theme.fgSurfaceVariant
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space2

                        Text {
                            Layout.fillWidth: true
                            text: detailPage.detail.name || detailPage.artistName || qsTr("Artist")
                            color: Theme.fgSurface
                            font: Theme.fontHeadlineMedium
                            elide: Text.ElideRight
                            wrapMode: Text.Wrap
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: detailPage.detail.description
                            text: detailPage.detail.description
                            color: Theme.fgSurfaceVariant
                            font: Theme.fontBodySmall
                            elide: Text.ElideRight
                            maximumLineCount: 3
                            wrapMode: Text.Wrap
                        }
                    }
                }

                Text {
                    Layout.leftMargin: Theme.space4
                    Layout.fillWidth: true
                    text: qsTr("Top tracks")
                    color: Theme.fgSurface
                    font: Theme.fontTitleLarge
                    visible: detailPage.tracks.length > 0
                }

                TrackList {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(200, detailPage.height - 300)
                    tracks: detailPage.tracks
                    currentTrackId: ""
                    emptyMessage: detailPage.loading
                        ? qsTr("Loading…")
                        : (detailPage.loadFailed
                            ? (detailPage.errorMessage || qsTr("Couldn't load this artist"))
                            : qsTr("No top tracks found"))
                    onPlayTrack: function(id) { Daemon.playTrack(id) }
                    onAddToQueue: function(id) { Daemon.addToQueue(id, false) }
                }

                Item { Layout.preferredHeight: Theme.space4 }
            }
        }
    }

    Connections {
        target: Daemon
        function onArtistDetailReceived(d) {
            detailPage.detail = d || {}
            detailPage.tracks = d.tracks || []
            if (!detailPage.artistName && d.name) detailPage.artistName = d.name
            detailPage.loading = false
            detailPage.loadFailed = false
        }
        function onArtistDetailError(err) {
            detailPage.loading = false
            detailPage.loadFailed = true
            detailPage.errorMessage = err || ""
        }
    }

    Component.onCompleted: {
        detailPage.loading = true
        detailPage.loadFailed = false
        Daemon.getArtistDetail(detailPage.artistId)
    }
}
