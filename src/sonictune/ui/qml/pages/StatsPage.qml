// pages/StatsPage.qml — listening stats: a listening-time donut, a grid of
// StatCards, plus top tracks/artists (Material 3).

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"

Item {
    id: statsPage

    property var stats: ({})
    property bool loading: true
    property bool loadError: false

    readonly property var hourly: JSON.parse(statsPage.stats.listening_by_hour_json || "[]")
    readonly property var topTracks: JSON.parse(statsPage.stats.top_tracks_json || "[]")
    readonly property var topArtists: JSON.parse(statsPage.stats.top_artists_json || "[]")
    readonly property var last30: JSON.parse(statsPage.stats.last_30_days_json || "[]")

    readonly property int totalListenMs: Number(statsPage.stats.total_listen_ms || 0)
    readonly property real listenShare: Math.min(1, totalListenMs / 86400000)
    readonly property int activeDays30: {
        var n = 0
        for (var i = 0; i < statsPage.last30.length; i++) {
            if (Number(statsPage.last30[i].count || 0) > 0) n++
        }
        return n
    }
    readonly property int plays30: {
        var n = 0
        for (var i = 0; i < statsPage.last30.length; i++) {
            n += Number(statsPage.last30[i].count || 0)
        }
        return n
    }
    readonly property bool hasData: Number(statsPage.stats.total_plays || 0) > 0
        || statsPage.topTracks.length > 0
        || statsPage.topArtists.length > 0
        || statsPage.hourly.length > 0

    Connections {
        target: Daemon
        function onStatsReceived(s) {
            statsPage.stats = s || {}
            statsPage.loading = false
            statsPage.loadError = false
        }
        function onStatsError(e) {
            statsPage.loading = false
            statsPage.loadError = true
        }
        function onConnectionChanged(c) { if (c) statsPage.reload() }
    }

    function reload() {
        statsPage.loading = true
        statsPage.loadError = false
        Daemon.getStats()
    }

    Component.onCompleted: { if (Daemon.isConnected()) statsPage.reload() }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true
        visible: statsPage.hasData

        ColumnLayout {
            width: statsPage.width
            spacing: Theme.space6

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.space6
                Layout.rightMargin: Theme.space6
                Layout.topMargin: Theme.space6
                Text { text: qsTr("Stats"); color: Theme.onSurface; font: Theme.fontHeadlineMedium }
                Item { Layout.fillWidth: true }
                IconButton {
                    icon: "sync"
                    diameter: 36
                    iconSize: 18
                    onClicked: statsPage.reload()
                }
            }

            // --- Donut + card grid ---------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.space6
                Layout.rightMargin: Theme.space6
                spacing: Theme.space6

                Rectangle {
                    Layout.preferredWidth: 220
                    Layout.preferredHeight: 220
                    radius: Theme.radiusLg
                    color: Theme.surfaceContainer

                    Canvas {
                        id: donut
                        anchors.centerIn: parent
                        width: 160
                        height: 160
                        property real share: statsPage.listenShare
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            var cx = width / 2
                            var cy = height / 2
                            var r = width / 2 - 14
                            ctx.lineWidth = 14
                            ctx.lineCap = "round"
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, 0, Math.PI * 2)
                            ctx.strokeStyle = Theme.playerProgressBg
                            ctx.stroke()
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * donut.share)
                            ctx.strokeStyle = Theme.primary
                            ctx.stroke()
                        }
                        onShareChanged: requestPaint()
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: statsPage.formatHours(statsPage.totalListenMs) + "h"
                            color: Theme.onSurface
                            font.family: Theme.fontFamilyMono
                            font.pixelSize: 28
                            font.weight: Font.Medium
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("listened")
                            color: Theme.onSurfaceVariant
                            font: Theme.fontLabelSmall
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    columns: statsPage.width > 1000 ? 3 : 2
                    columnSpacing: Theme.space4
                    rowSpacing: Theme.space4

                    StatCard {
                        Layout.fillWidth: true
                        icon: "stats"
                        title: qsTr("Total plays")
                        value: Theme.formatNumber(Number(statsPage.stats.total_plays || 0))
                        subtitle: qsTr("all time")
                    }
                    StatCard {
                        Layout.fillWidth: true
                        icon: "clock"
                        title: qsTr("Hours listened")
                        value: statsPage.formatHours(statsPage.totalListenMs) + "h"
                        subtitle: qsTr("total listening time")
                    }
                    StatCard {
                        Layout.fillWidth: true
                        icon: "note"
                        title: qsTr("Unique tracks")
                        value: Theme.formatNumber(Number(statsPage.stats.unique_tracks || 0))
                        subtitle: qsTr("distinct songs")
                    }
                    StatCard {
                        Layout.fillWidth: true
                        icon: "person"
                        title: qsTr("Unique artists")
                        value: Theme.formatNumber(Number(statsPage.stats.unique_artists || 0))
                        subtitle: qsTr("distinct artists")
                    }
                    StatCard {
                        Layout.fillWidth: true
                        icon: "check"
                        title: qsTr("Active days (30d)")
                        value: String(statsPage.activeDays30)
                        subtitle: qsTr("days with plays")
                    }
                    StatCard {
                        Layout.fillWidth: true
                        icon: "play_circle"
                        title: qsTr("Plays (30d)")
                        value: Theme.formatNumber(statsPage.plays30)
                        subtitle: qsTr("last 30 days")
                    }
                }
            }

            // --- Top tracks + artists -------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.space6
                Layout.rightMargin: Theme.space6
                Layout.bottomMargin: Theme.space6
                spacing: Theme.space6

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space3
                    Text { text: qsTr("Top tracks"); color: Theme.onSurface; font: Theme.fontTitleLarge }
                    TrackList {
                        Layout.fillWidth: true
                        tracks: statsPage.topTracks
                        emptyMessage: qsTr("Play something to see your top tracks")
                        onPlayTrack: function(id) { Daemon.playTrack(id) }
                        onAddToQueue: function(id) { Daemon.addToQueue(id, false) }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space3
                    Text { text: qsTr("Top artists"); color: Theme.onSurface; font: Theme.fontTitleLarge }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Repeater {
                            model: statsPage.topArtists
                            delegate: RowLayout {
                                id: artistRow
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                spacing: Theme.space3

                                Text {
                                    text: (artistRow.index + 1) + "."
                                    color: Theme.onSurfaceVariant
                                    font: Theme.fontMono
                                    Layout.preferredWidth: 24
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: artistRow.modelData.artist || ""
                                    color: Theme.onSurface
                                    font: Theme.fontBodyLarge
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: String(artistRow.modelData.count || 0)
                                    color: Theme.onSurfaceVariant
                                    font: Theme.fontMono
                                }
                            }
                        }

                        Text {
                            visible: statsPage.topArtists.length === 0
                            text: qsTr("No data yet")
                            color: Theme.onSurfaceVariant
                            font: Theme.fontBodyMedium
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: !statsPage.loading && (statsPage.loadError || !statsPage.hasData)
        spacing: Theme.space4
        width: 320

        Icon {
            Layout.alignment: Qt.AlignHCenter
            name: statsPage.loadError ? "warning" : "stats"
            size: 32
            color: Theme.onSurfaceVariant
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: statsPage.loadError ? qsTr("Couldn't load your stats") : qsTr("No listening stats yet")
            color: Theme.onSurface
            font: Theme.fontTitleMedium
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: statsPage.loadError
                ? qsTr("Try again in a moment.")
                : qsTr("Play some music and check back to see how your listening is trending.")
            color: Theme.onSurfaceVariant
            font: Theme.fontBodySmall
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
        STButton {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Try again")
            variant: "tonal"
            onClicked: statsPage.reload()
        }
    }

    LoadingOverlay {
        opacity: statsPage.loading ? 1 : 0
        message: qsTr("Crunching your stats…")
    }

    function formatHours(ms) {
        var hrs = ms / 3600000
        return hrs < 10 ? hrs.toFixed(1) : String(Math.round(hrs))
    }
}
