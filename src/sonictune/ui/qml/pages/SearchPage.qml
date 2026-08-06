// pages/SearchPage.qml — search with debounce, filter chips, recent
// searches, and TrackList results (Material 3).

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"
import "../router"

Item {
    id: searchPage
    objectName: "searchPage"

    property var results: []
    property var recentSearches: []
    property string activeFilter: ""
    property bool loading: false
    property bool searched: false
    property bool searchFailed: false
    property string searchErrorMessage: ""

    readonly property var filters: [
        { key: "", label: qsTr("All") },
        { key: "songs", label: qsTr("Songs") },
        { key: "albums", label: qsTr("Albums") },
        { key: "artists", label: qsTr("Artists") },
        { key: "playlists", label: qsTr("Playlists") }
    ]

    property string lastQuery: ""

    readonly property var songResults: searchPage.results.filter(function (r) {
        return r.resultType !== "album" && r.resultType !== "artist" && r.resultType !== "playlist"
    })
    readonly property var albumResults: searchPage.results.filter(function (r) { return r.resultType === "album" })
    readonly property var artistResults: searchPage.results.filter(function (r) { return r.resultType === "artist" })
    readonly property var playlistResults: searchPage.results.filter(function (r) { return r.resultType === "playlist" })

    Connections {
        target: Daemon
        function onSearchCompleted(r) {
            searchPage.results = r || []
            searchPage.loading = false
            searchPage.searchFailed = false
            if (searchPage.lastQuery) {
                Daemon.recordSearch(searchPage.lastQuery, (r || []).length)
            }
        }
        function onSearchError(err) {
            searchPage.loading = false
            searchPage.searchFailed = true
            searchPage.searchErrorMessage = err || ""
        }
        function onSearchHistoryReceived(h) {
            searchPage.recentSearches = h || []
        }
        function onSearchHistoryError(err) {
            searchPage.recentSearches = []
        }
    }

    Component.onCompleted: Daemon.getSearchHistory()

    // 300ms debounce after typing stops.
    Timer {
        id: debounce
        interval: 300
        onTriggered: searchPage.runSearch()
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

        Text {
            text: qsTr("Search")
            color: Theme.fgSurface
            font: Theme.fontHeadlineMedium
        }

        // --- Search bar ------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: Theme.radiusFull
            color: Theme.surfaceContainerHigh
            border.width: 1
            border.color: searchField.activeFocus ? Theme.primary : Theme.outline

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space4
                anchors.rightMargin: Theme.space3
                spacing: Theme.space2

                Icon { name: "search"; size: 18; color: Theme.fgSurfaceVariant }

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    placeholderText: qsTr("Search songs, albums, artists, playlists…")
                    placeholderTextColor: Theme.fgSurfaceVariant
                    background: Item {}
                    color: Theme.fgSurface
                    selectionColor: Theme.primaryContainer
                    onTextChanged: {
                        debounce.restart()
                        if (searchField.text.trim() === "") {
                            searchPage.results = []
                            searchPage.searched = false
                            searchPage.searchFailed = false
                        }
                    }
                    onAccepted: { debounce.stop(); searchPage.runSearch() }
                }

                IconButton {
                    icon: "close"
                    diameter: 28
                    iconSize: 14
                    visible: searchField.text.length > 0
                    onClicked: searchPage.clearResults()
                }
            }
        }

        // --- Filter chips -------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space2

            Repeater {
                model: searchPage.filters
                delegate: Rectangle {
                    id: filterChip
                    required property var modelData

                    readonly property bool active: searchPage.activeFilter === filterChip.modelData.key

                    Layout.preferredHeight: 36
                    Layout.preferredWidth: filterLabel.implicitWidth + Theme.space6
                    radius: Theme.radiusFull
                    color: filterChip.active ? Theme.primaryContainer : Theme.surfaceContainer
                    border.color: filterChip.active ? Theme.primary : Theme.outline
                    border.width: 1
                    Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.durFast } }

                    Text {
                        id: filterLabel
                        anchors.centerIn: parent
                        text: filterChip.modelData.label
                        color: filterChip.active ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
                        font: Theme.fontLabelLarge
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchPage.activeFilter = filterChip.modelData.key
                            if (searchField.text.trim()) searchPage.runSearch()
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        // --- Recent searches (before anything is searched) ----------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.space2
            visible: !searchPage.searched && searchPage.recentSearches.length > 0

            Text {
                text: qsTr("Recent searches")
                color: Theme.fgSurfaceVariant
                font: Theme.fontLabelMedium
            }

            Flow {
                Layout.fillWidth: true
                spacing: Theme.space2

                Repeater {
                    model: searchPage.recentSearches
                    delegate: Rectangle {
                        id: recentChip
                        required property var modelData

                        radius: Theme.radiusFull
                        color: Theme.surfaceContainer
                        border.width: 1
                        border.color: Theme.outline
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: recentLabel.implicitWidth + Theme.space6

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Theme.space2
                            Icon { name: "clock"; size: 13; color: Theme.fgSurfaceVariant }
                            Text {
                                id: recentLabel
                                text: recentChip.modelData.query || ""
                                color: Theme.fgSurfaceVariant
                                font: Theme.fontBodySmall
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchField.text = recentChip.modelData.query || ""
                                searchPage.runSearch()
                            }
                        }
                    }
                }
            }
        }

        // --- Results ----------------------------------------------------------
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            visible: searchPage.searched && !searchPage.loading && !searchPage.searchFailed

            ColumnLayout {
                width: searchPage.width - Theme.space6 * 2
                spacing: Theme.space6

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space2
                    visible: searchPage.songResults.length > 0

                    Text { text: qsTr("Songs"); color: Theme.fgSurfaceVariant; font: Theme.fontLabelMedium }
                    TrackList {
                        Layout.fillWidth: true
                        tracks: searchPage.songResults
                        emptyMessage: qsTr("No songs found")
                        onPlayTrack: function(id) { Daemon.playTrack(id) }
                        onAddToQueue: function(id) { Daemon.addToQueue(id, false) }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space2
                    visible: searchPage.albumResults.length > 0

                    Text { text: qsTr("Albums"); color: Theme.fgSurfaceVariant; font: Theme.fontLabelMedium }
                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.space4
                        Repeater {
                            model: searchPage.albumResults
                            delegate: AlbumCard {
                                id: albumItem
                                required property var modelData
                                title: albumItem.modelData.title || ""
                                subtitle: albumItem.modelData.artist || albumItem.modelData.author || ""
                                thumbnailUrl: albumItem.modelData.thumbnail_url || ""
                                onClicked: Router.pushPage("AlbumDetailPage.qml", {
                                    albumId: albumItem.modelData.browse_id || "",
                                    albumTitle: albumItem.modelData.title || ""
                                })
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space2
                    visible: searchPage.artistResults.length > 0

                    Text { text: qsTr("Artists"); color: Theme.fgSurfaceVariant; font: Theme.fontLabelMedium }
                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.space4
                        Repeater {
                            model: searchPage.artistResults
                            delegate: ArtistCard {
                                id: artistItem
                                required property var modelData
                                name: artistItem.modelData.name || artistItem.modelData.title || ""
                                thumbnailUrl: artistItem.modelData.thumbnail_url || ""
                                onClicked: Router.pushPage("ArtistDetailPage.qml", {
                                    artistId: artistItem.modelData.browse_id || "",
                                    artistName: artistItem.modelData.name || artistItem.modelData.title || ""
                                })
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space2
                    visible: searchPage.playlistResults.length > 0

                    Text { text: qsTr("Playlists"); color: Theme.fgSurfaceVariant; font: Theme.fontLabelMedium }
                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.space4
                        Repeater {
                            model: searchPage.playlistResults
delegate: PlaylistCard {
                            id: playlistItem
                            required property var modelData
                            title: playlistItem.modelData.title || ""
                            subtitle: playlistItem.modelData.author || ""
                            playlistId: playlistItem.modelData.browse_id || ""
                            thumbnailUrl: playlistItem.modelData.thumbnail_url || ""
                            onClicked: Router.pushPage("PlaylistDetailPage.qml", {
                                playlistId: playlistItem.modelData.browse_id || "",
                                playlistTitle: playlistItem.modelData.title || ""
                            })
                        }
                        }
                    }
                }

                Item { Layout.preferredHeight: Theme.space4 }
            }
        }

        // --- Empty state -------------------------------------------------------
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.space10
            visible: searchPage.searched && !searchPage.loading && !searchPage.searchFailed && searchPage.results.length === 0
            spacing: Theme.space3
            width: 320

            Icon { Layout.alignment: Qt.AlignHCenter; name: "search"; size: 32; color: Theme.fgSurfaceVariant }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                text: qsTr("No results for \"%1\"").arg(searchPage.lastQuery)
                color: Theme.fgSurface
                font: Theme.fontTitleMedium
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Try a different search, or browse the home feed.")
                color: Theme.fgSurfaceVariant
                font: Theme.fontBodySmall
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // --- Error state -------------------------------------------------------
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.space10
            visible: searchPage.searchFailed && !searchPage.loading
            spacing: Theme.space3
            width: 320

            Icon { Layout.alignment: Qt.AlignHCenter; name: "warning"; size: 32; color: Theme.fgSurfaceVariant }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                text: qsTr("Search failed")
                color: Theme.fgSurface
                font: Theme.fontTitleMedium
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                text: searchPage.searchErrorMessage
                color: Theme.fgSurfaceVariant
                font: Theme.fontBodySmall
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
            STButton {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Try again")
                variant: "tonal"
                onClicked: searchPage.runSearch()
            }
        }

        Item { Layout.fillHeight: true }
    }

    LoadingOverlay {
        opacity: searchPage.loading ? 1 : 0
        message: qsTr("Searching…")
    }

    function runSearch() {
        var q = searchField.text.trim()
        if (!q) return
        searchPage.loading = true
        searchPage.searched = true
        searchPage.searchFailed = false
        searchPage.lastQuery = q
        Daemon.search(q, searchPage.activeFilter, 20)
    }

    function searchFor(q) {
        searchField.text = q || ""
        searchPage.runSearch()
    }

    function focusSearch() {
        pageFocusTimer.restart()
    }

    Timer {
        id: pageFocusTimer
        interval: 50
        onTriggered: {
            searchField.forceActiveFocus()
            searchField.selectAll()
        }
    }

    function clearResults() {
        searchField.text = ""
        debounce.stop()
        searchPage.results = []
        searchPage.searched = false
        searchPage.searchFailed = false
    }
}
