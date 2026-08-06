// pages/AlbumDetailPage.qml — album detail view pushed onto the navigation
// stack by Router. Fetches the tracklist via Daemon.getAlbumDetail() and
// renders it in a TrackList with Play All + header artwork.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"
import "../router"

Item {
    id: detailPage

    property string albumId: ""
    property string albumTitle: ""
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
                    text: detailPage.albumTitle || qsTr("Album")
                    color: Theme.fgSurface
                    font: Theme.fontHeadlineSmall
                    elide: Text.ElideRight
                }
                Text {
                    text: detailPage.detail.artist || ""
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

        // --- Artwork banner + tracklist -----------------------------------
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
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Theme.space4

                    Rectangle {
                        Layout.preferredWidth: 160
                        Layout.preferredHeight: 160
                        radius: Theme.radiusMd
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
                            name: "album"
                            size: 40
                            color: Theme.fgSurfaceVariant
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space2

                        Text {
                            Layout.fillWidth: true
                            text: detailPage.detail.title || detailPage.albumTitle || qsTr("Album")
                            color: Theme.fgSurface
                            font: Theme.fontHeadlineMedium
                            elide: Text.ElideRight
                            wrapMode: Text.Wrap
                        }
                        Text {
                            Layout.fillWidth: true
                            text: {
                                var parts = []
                                if (detailPage.detail.artist) parts.push(detailPage.detail.artist)
                                if (detailPage.detail.year) parts.push(detailPage.detail.year)
                                return parts.join(" · ")
                            }
                            color: Theme.fgSurfaceVariant
                            font: Theme.fontBodyMedium
                        }
                        Text {
                            Layout.fillWidth: true
                            text: qsTr("%n track(s)", "", detailPage.tracks.length)
                            color: Theme.fgSurfaceVariant
                            font: Theme.fontBodySmall
                        }
                    }
                }

                TrackList {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(200, detailPage.height - 300)
                    tracks: detailPage.tracks
                    currentTrackId: ""
                    emptyMessage: detailPage.loading
                        ? qsTr("Loading…")
                        : (detailPage.loadFailed
                            ? (detailPage.errorMessage || qsTr("Couldn't load this album"))
                            : qsTr("This album has no tracks"))
                    onPlayTrack: function(id) { Daemon.playTrack(id) }
                    onAddToQueue: function(id) { Daemon.addToQueue(id, false) }
                }

                Item { Layout.preferredHeight: Theme.space4 }
            }
        }
    }

    Connections {
        target: Daemon
        function onAlbumDetailReceived(d) {
            detailPage.detail = d || {}
            detailPage.tracks = d.tracks || []
            if (!detailPage.albumTitle && d.title) detailPage.albumTitle = d.title
            detailPage.loading = false
            detailPage.loadFailed = false
        }
        function onAlbumDetailError(err) {
            detailPage.loading = false
            detailPage.loadFailed = true
            detailPage.errorMessage = err || ""
        }
    }

    Component.onCompleted: {
        detailPage.loading = true
        detailPage.loadFailed = false
        Daemon.getAlbumDetail(detailPage.albumId)
    }
}
