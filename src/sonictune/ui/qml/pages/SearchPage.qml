// pages/SearchPage.qml — search with debounce, filter chips, and results.
// BUGFIX: searches now debounce 300ms after typing stops (was search-on-Enter
// only), so results appear as you type.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import "../theme"
import "../components"

Item {
    id: searchPage

    property var results: []
    property var recentSearches: []
    property string activeFilter: ""
    property bool loading: false
    property bool searched: false

    readonly property var filters: [
        { key: "", label: qsTr("All") },
        { key: "songs", label: qsTr("Songs") },
        { key: "albums", label: qsTr("Albums") },
        { key: "artists", label: qsTr("Artists") },
        { key: "playlists", label: qsTr("Playlists") }
    ]

    property string lastQuery: ""

    Connections {
        target: Daemon
        function onSearchCompleted(r) {
            searchPage.results = r || []
            searchPage.loading = false
            if (searchPage.lastQuery) {
                Daemon.recordSearch(searchPage.lastQuery, (r || []).length)
            }
        }
        function onSearchError(err) {
            searchPage.loading = false
        }
        function onSearchHistoryReceived(h) {
            searchPage.recentSearches = h || []
        }
    }

    Component.onCompleted: Daemon.getSearchHistory()

    // 300ms debounce after typing stops.
    Timer {
        id: debounce
        interval: 300
        onTriggered: searchPage.runSearch()
    }

    function runSearch() {
        var q = searchField.text.trim()
        if (!q) return
        searchPage.loading = true
        searchPage.searched = true
        searchPage.lastQuery = q
        Daemon.search(q, searchPage.activeFilter, 30)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingLg
        spacing: Theme.spacingMd

        Text { text: qsTr("Search"); color: Theme.onSurface; font: Theme.fontHeadlineMedium }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: Theme.radiusMd
            color: Theme.surface
            border.color: searchField.activeFocus ? Theme.primary : Theme.outline
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingMd
                anchors.rightMargin: Theme.spacingSm
                spacing: Theme.spacingSm

                Icon { name: "search"; size: 18; color: Theme.onSurfaceVariant }

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Search songs, albums, artists, playlists…")
                    background: Item {}
                    color: Theme.onSurface
                    selectionColor: Theme.primaryContainer
                    onTextChanged: {
                        debounce.restart()
                        if (searchField.text.trim() === "") {
                            searchPage.results = []
                            searchPage.searched = false
                        }
                    }
                    onAccepted: { debounce.stop(); searchPage.runSearch() }
                }

                Item {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    visible: searchField.text.length > 0
                    Icon { anchors.centerIn: parent; name: "close"; size: 14; color: Theme.onSurfaceVariant }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchField.text = ""
                            debounce.stop()
                            searchPage.results = []
                            searchPage.searched = false
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            Repeater {
                model: searchPage.filters
                delegate: Rectangle {
                    id: filterChip
                    required property var modelData
                    readonly property bool active: searchPage.activeFilter === modelData.key
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: filterLabel.implicitWidth + Theme.spacingLg
                    radius: Theme.radiusFull
                    color: filterChip.active ? Theme.primaryContainer : Theme.surface
                    border.color: filterChip.active ? Theme.primary : Theme.outline
                    border.width: 1

                    Text {
                        id: filterLabel
                        anchors.centerIn: parent
                        text: filterChip.modelData.label
                        color: filterChip.active ? Theme.primary : Theme.onSurfaceVariant
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

        // --- Recent searches, shown before any results ------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXs
            visible: !searchPage.searched && searchPage.recentSearches.length > 0

            Text { text: qsTr("Recent searches"); color: Theme.onSurfaceVariant; font: Theme.fontLabelSmall }

            Flow {
                Layout.fillWidth: true
                spacing: Theme.spacingSm

                Repeater {
                    model: searchPage.recentSearches
                    delegate: Rectangle {
                        id: recentChip
                        required property var modelData
                        radius: Theme.radiusFull
                        color: Theme.surface
                        border.width: 1
                        border.color: Theme.outline
                        height: 36
                        width: recentLabel.implicitWidth + Theme.spacingLg

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Icon { name: "clock"; size: 12; color: Theme.onSurfaceVariant }
                            Text {
                                id: recentLabel
                                text: recentChip.modelData.query || ""
                                color: Theme.onSurfaceVariant
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

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            visible: searchPage.searched && !searchPage.loading

            ColumnLayout {
                width: searchPage.width - Theme.spacingLg * 2
                spacing: Theme.spacingSm

                Repeater {
                    model: searchPage.results

                    delegate: Item {
                        id: resultItem
                        required property var modelData

                        Layout.fillWidth: true
                        readonly property bool isTrack: modelData.resultType !== "album" && modelData.resultType !== "artist" && modelData.resultType !== "playlist"
                        Layout.preferredHeight: resultItem.isTrack ? 60 : 96

                        TrackList {
                            anchors.fill: parent
                            visible: resultItem.isTrack
                            tracks: resultItem.isTrack ? [resultItem.modelData] : []
                            onPlayTrack: function(id) { Daemon.playTrack(id) }
                            onAddToQueue: function(id) { Daemon.addToQueue(id, false) }
                        }

                        RowLayout {
                            anchors.fill: parent
                            visible: resultItem.modelData.resultType === "album"
                            spacing: Theme.spacingMd
                            AlbumCard {
                                title: resultItem.modelData.title || ""
                                subtitle: (resultItem.modelData.artists || []).map(function(a) { return a.name }).join(", ")
                                thumbnailUrl: (resultItem.modelData.thumbnails && resultItem.modelData.thumbnails.length) ? resultItem.modelData.thumbnails[resultItem.modelData.thumbnails.length - 1].url : ""
                                onClicked: Daemon.search(title, "songs", 20)
                            }
                            Item { Layout.fillWidth: true }
                        }

                        RowLayout {
                            anchors.fill: parent
                            visible: resultItem.modelData.resultType === "artist"
                            spacing: Theme.spacingMd
                            ArtistCard {
                                name: resultItem.modelData.artist || resultItem.modelData.title || ""
                                thumbnailUrl: (resultItem.modelData.thumbnails && resultItem.modelData.thumbnails.length) ? resultItem.modelData.thumbnails[resultItem.modelData.thumbnails.length - 1].url : ""
                                onClicked: Daemon.search(name, "songs", 20)
                            }
                            Item { Layout.fillWidth: true }
                        }

                        RowLayout {
                            anchors.fill: parent
                            visible: resultItem.modelData.resultType === "playlist"
                            spacing: Theme.spacingMd
                            PlaylistCard {
                                title: resultItem.modelData.title || ""
                                subtitle: resultItem.modelData.author || ""
                                thumbnailUrl: (resultItem.modelData.thumbnails && resultItem.modelData.thumbnails.length) ? resultItem.modelData.thumbnails[resultItem.modelData.thumbnails.length - 1].url : ""
                                onClicked: Daemon.search(title, "songs", 20)
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.spacingXxl
            visible: searchPage.searched && !searchPage.loading && searchPage.results.length === 0
            spacing: Theme.spacingSm

            Icon { Layout.alignment: Qt.AlignHCenter; name: "search"; size: 28; color: Theme.onSurfaceVariant }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("No results found")
                color: Theme.onSurfaceVariant
                font: Theme.fontBodyMedium
            }
        }

        Item { Layout.fillHeight: !searchPage.searched }
    }

    LoadingOverlay {
        opacity: searchPage.loading ? 1 : 0
        message: qsTr("Searching…")
    }
}
