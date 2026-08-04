// pages/LibraryPage.qml — signed-in user's saved songs/albums/playlists,
// plus a Local Files stub tab (Material 3).

import QtQuick
import QtQuick.Controls
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

    signal navigateRequested(string pageName)
    function pageStackSwitch(name) { navigateRequested(name) }

    Connections {
        target: Daemon
        function onLibrarySongsReceived(s) { libraryPage.songs = s || []; libraryPage.loading = false }
        function onLibrarySongsError(e) { libraryPage.loading = false }
        function onLibraryAlbumsReceived(a) { libraryPage.albums = a || []; libraryPage.loading = false }
        function onLibraryAlbumsError(e) { libraryPage.loading = false }
        function onLibraryPlaylistsReceived(p) { libraryPage.playlists = p || []; libraryPage.loading = false }
        function onLibraryPlaylistsError(e) { libraryPage.loading = false }
        function onAuthChanged(a) {
            libraryPage.authenticated = a
            if (a) libraryPage.loadAll()
        }
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
        visible: libraryPage.authenticated

        RowLayout {
            Layout.fillWidth: true
            Text { text: qsTr("Library"); color: Theme.onSurface; font: Theme.fontHeadlineMedium }
            Item { Layout.fillWidth: true }
            STButton {
                text: qsTr("Sync")
                iconName: "sync"
                variant: "tonal"
                onClicked: { libraryPage.loading = true; Daemon.syncLibrary() }
            }
        }

        TabBar {
            id: tabBar
            Layout.fillWidth: true
            Material.accent: Theme.primary

            TabButton { text: qsTr("Songs (%1)").arg(libraryPage.songs.length) }
            TabButton { text: qsTr("Albums (%1)").arg(libraryPage.albums.length) }
            TabButton { text: qsTr("Playlists (%1)").arg(libraryPage.playlists.length) }
            TabButton { text: qsTr("Local Files") }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

// --- Songs ----------------------------------------------------
TrackList {
    Layout.fillWidth: true
    Layout.fillHeight: true
    width: libraryPage.width - Theme.space6 * 2
    tracks: libraryPage.songs
    emptyMessage: qsTr("Your library is empty")
    onPlayTrack: function(id) { Daemon.playTrack(id) }
    onAddToQueue: function(id) { Daemon.addToQueue(id, false) }
}

            // --- Albums ---------------------------------------------------
            ScrollView {
                contentWidth: availableWidth
                clip: true

                ColumnLayout {
                    width: libraryPage.width - Theme.space6 * 2
                    spacing: Theme.space4

                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.space4
                        visible: libraryPage.albums.length > 0

                        Repeater {
                            model: libraryPage.albums
                            delegate: AlbumCard {
                                id: albumItem
                                required property var modelData
                                title: albumItem.modelData.title || ""
                                subtitle: albumItem.modelData.artist || ""
                                thumbnailUrl: albumItem.modelData.thumbnail_url || ""
                                browseId: albumItem.modelData.browse_id || ""
                                onClicked: Daemon.search(albumItem.modelData.title || "", "songs", 20)
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Theme.space10
                        spacing: Theme.space3
                        visible: libraryPage.albums.length === 0

                        Icon { Layout.alignment: Qt.AlignHCenter; name: "album"; size: 32; color: Theme.onSurfaceVariant }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("No albums saved yet")
                            color: Theme.onSurface
                            font: Theme.fontTitleMedium
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("Albums you save will show up here.")
                            color: Theme.onSurfaceVariant
                            font: Theme.fontBodySmall
                        }
                    }
                }
            }

            // --- Playlists ---------------------------------------------------
            ScrollView {
                contentWidth: availableWidth
                clip: true

                ColumnLayout {
                    width: libraryPage.width - Theme.space6 * 2
                    spacing: Theme.space4

                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.space4
                        visible: libraryPage.playlists.length > 0

                        Repeater {
                            model: libraryPage.playlists
                            delegate: PlaylistCard {
                                id: playlistItem
                                required property var modelData
                                title: playlistItem.modelData.title || ""
                                subtitle: playlistItem.modelData.owner || ""
                                trackCount: playlistItem.modelData.track_count || 0
                                thumbnailUrl: playlistItem.modelData.thumbnail_url || ""
                                onClicked: Daemon.search(playlistItem.modelData.title || "", "songs", 20)
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Theme.space10
                        spacing: Theme.space3
                        visible: libraryPage.playlists.length === 0

                        Icon { Layout.alignment: Qt.AlignHCenter; name: "queue"; size: 32; color: Theme.onSurfaceVariant }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("No playlists saved yet")
                            color: Theme.onSurface
                            font: Theme.fontTitleMedium
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("Playlists you save will show up here.")
                            color: Theme.onSurfaceVariant
                            font: Theme.fontBodySmall
                        }
                    }
                }
            }

            // --- Local Files (stub) -------------------------------------------
            Item {
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Theme.space3
                    width: 360

                    Icon { Layout.alignment: Qt.AlignHCenter; name: "download"; size: 32; color: Theme.onSurfaceVariant }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Local files coming soon")
                        color: Theme.onSurface
                        font: Theme.fontTitleMedium
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        text: qsTr("Soon you'll be able to browse music stored on this device. For now, search the catalog to play anything.")
                        color: Theme.onSurfaceVariant
                        font: Theme.fontBodySmall
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: !libraryPage.authenticated
        spacing: Theme.space4
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
        STButton {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Go to Settings")
            variant: "filled"
            onClicked: libraryPage.navigateRequested("settings")
        }
    }

    LoadingOverlay {
        opacity: libraryPage.loading ? 1 : 0
        message: qsTr("Syncing your library…")
    }
}
