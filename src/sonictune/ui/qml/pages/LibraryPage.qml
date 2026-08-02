// pages/LibraryPage.qml — the signed-in user's saved songs/albums/playlists.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import "../theme"
import "../components"

Item {
    id: libraryPage

    property var songs: []
    property var albums: []
    property var playlists: []
    property bool loading: false
    property bool authenticated: false

    Connections {
        target: Daemon
        function onLibrarySongsReceived(s) { libraryPage.songs = s || []; libraryPage.loading = false }
        function onLibrarySongsError(e) { libraryPage.loading = false }
        function onLibraryAlbumsReceived(a) { libraryPage.albums = a || [] }
        function onLibraryPlaylistsReceived(p) { libraryPage.playlists = p || [] }
        function onAuthChanged(a) { libraryPage.authenticated = a; if (a) libraryPage.loadAll() }
        function onSyncLibraryCompleted(r) { libraryPage.loading = false; libraryPage.loadAll() }
        function onSyncLibraryError(e) { libraryPage.loading = false }
    }

    Component.onCompleted: {
        libraryPage.authenticated = Daemon.isAuthenticated()
        if (libraryPage.authenticated) libraryPage.loadAll()
    }

    function loadAll() {
        libraryPage.loading = true
        Daemon.getLibrarySongs()
        Daemon.getLibraryAlbums()
        Daemon.getLibraryPlaylists()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingLg
        spacing: Theme.spacingMd
        visible: libraryPage.authenticated

        RowLayout {
            Layout.fillWidth: true
            Text { text: qsTr("Library"); color: Theme.onSurface; font: Theme.fontHeadlineMedium }
            Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Sync")
                flat: true
                onClicked: { libraryPage.loading = true; Daemon.syncLibrary() }
            }
        }

        TabBar {
            id: tabBar
            Layout.fillWidth: true
            Material.accent: Theme.primary
            background: Rectangle { color: "transparent" }

            TabButton { text: qsTr("Songs (%1)").arg(libraryPage.songs.length) }
            TabButton { text: qsTr("Albums (%1)").arg(libraryPage.albums.length) }
            TabButton { text: qsTr("Playlists (%1)").arg(libraryPage.playlists.length) }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            ScrollView {
                contentWidth: availableWidth
                TrackList {
                    width: libraryPage.width - Theme.spacingLg * 2
                    tracks: libraryPage.songs
                    emptyMessage: qsTr("No saved songs yet")
                    onPlayTrack: function(id) { Daemon.playTrack(id) }
                    onAddToQueue: function(id) { Daemon.addToQueue(id, false) }
                }
            }

            ScrollView {
                contentWidth: availableWidth
                Flow {
                    width: libraryPage.width - Theme.spacingLg * 2
                    spacing: Theme.spacingMd
                    Repeater {
                        model: libraryPage.albums
                        delegate: AlbumCard {
                            id: albumItem
                            required property var modelData
                            title: albumItem.modelData.title || ""
                            subtitle: (albumItem.modelData.artists || []).map(function(a) { return a.name }).join(", ")
                            thumbnailUrl: (albumItem.modelData.thumbnails && albumItem.modelData.thumbnails.length) ? albumItem.modelData.thumbnails[albumItem.modelData.thumbnails.length - 1].url : ""
                            onClicked: Daemon.search(title, "songs", 20)
                        }
                    }
                }
            }

            ScrollView {
                contentWidth: availableWidth
                Flow {
                    width: libraryPage.width - Theme.spacingLg * 2
                    spacing: Theme.spacingMd
                    Repeater {
                        model: libraryPage.playlists
                        delegate: PlaylistCard {
                            id: playlistItem
                            required property var modelData
                            title: playlistItem.modelData.title || ""
                            subtitle: playlistItem.modelData.author || ""
                            trackCount: playlistItem.modelData.count || 0
                            thumbnailUrl: (playlistItem.modelData.thumbnails && playlistItem.modelData.thumbnails.length) ? playlistItem.modelData.thumbnails[playlistItem.modelData.thumbnails.length - 1].url : ""
                            onClicked: Daemon.search(title, "songs", 20)
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: !libraryPage.authenticated
        spacing: Theme.spacingMd
        width: 320

        Icon { Layout.alignment: Qt.AlignHCenter; name: "library"; size: 32; color: Theme.onSurfaceVariant }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Sign in to see your library")
            color: Theme.onSurface
            font: Theme.fontTitleMedium
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: qsTr("Your saved songs, albums, and playlists show up here once you're signed in to YouTube Music.")
            color: Theme.onSurfaceVariant
            font: Theme.fontBodySmall
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
        Button {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Go to Settings")
            highlighted: true
            Material.accent: Theme.primary
            onClicked: libraryPage.pageStackSwitch("settings")
        }
    }

    LoadingOverlay {
        opacity: libraryPage.loading ? 1 : 0
        message: qsTr("Syncing your library…")
    }

    // main.qml's StackLayout owns navigation; reach it via the shared
    // Daemon-style pattern isn't available here, so expose a tiny signal
    // instead and let main.qml wire it once, same as PlayerBar does.
    signal navigateRequested(string pageName)
    function pageStackSwitch(name) { navigateRequested(name) }
}
