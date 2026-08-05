// pages/PlaylistDetailPage.qml — playlist detail view pushed onto the
// navigation stack by Router. Fetches tracks via Daemon.getPlaylistTracks()
// and renders them in a TrackList with a Play All action.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"
import "../router"

Item {
    id: detailPage

    property string playlistId: ""
    property string playlistTitle: ""
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
                iconName: "arrow_back"
                iconSize: 18
                toolTip: qsTr("Back")
                onClicked: Router.popPage()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: detailPage.playlistTitle || qsTr("Playlist")
                    color: Theme.fgSurface
                    font: Theme.fontHeadlineSmall
                    elide: Text.ElideRight
                }
                Text {
                    text: qsTr("%n track(s)", "", detailPage.tracks.length)
                    color: Theme.fgSurfaceVariant
                    font: Theme.fontBodySmall
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

        // --- Tracks -------------------------------------------------------
        TrackList {
            Layout.fillWidth: true
            Layout.fillHeight: true
            tracks: detailPage.tracks
            currentVideoId: ""
            emptyMessage: detailPage.loading
                ? qsTr("Loading…")
                : (detailPage.loadFailed
                    ? (detailPage.errorMessage || qsTr("Couldn't load this playlist"))
                    : qsTr("This playlist has no tracks"))
            onPlayTrack: function(id) { Daemon.playTrack(id) }
            onAddToQueue: function(id) { Daemon.addToQueue(id, false) }
        }

        Item { Layout.preferredHeight: 8 }
    }

    Connections {
        target: Daemon
        function onPlaylistTracksReceived(id, list) {
            if (id !== detailPage.playlistId) return
            detailPage.tracks = list || []
            detailPage.loading = false
            detailPage.loadFailed = false
        }
        function onPlaylistTracksError(id, err) {
            if (id !== detailPage.playlistId) return
            detailPage.loading = false
            detailPage.loadFailed = true
            detailPage.errorMessage = err || ""
        }
    }

    Component.onCompleted: {
        detailPage.loading = true
        detailPage.loadFailed = false
        Daemon.getPlaylistTracks(detailPage.playlistId)
    }
}
