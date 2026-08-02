// pages/StatsPage.qml — listening stats: totals, an hour-of-day chart, and
// top tracks/artists.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import "../theme"
import "../components"

Item {
    id: statsPage

    property var stats: ({})
    property bool loading: true

    Connections {
        target: Daemon
        function onStatsReceived(s) { statsPage.stats = s || {}; statsPage.loading = false }
        function onStatsError(e) { statsPage.loading = false }
        function onConnectionChanged(c) { if (c) statsPage.reload() }
    }

    function reload() {
        statsPage.loading = true
        Daemon.getStats()
    }

    Component.onCompleted: { if (Daemon.connected) statsPage.reload() }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: statsPage.width
            spacing: Theme.spacingLg

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Theme.spacingLg
                Layout.bottomMargin: 0
                Text { text: qsTr("Stats"); color: Theme.onSurface; font: Theme.fontHeadlineMedium }
                Item { Layout.fillWidth: true }
                Item {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Icon { anchors.centerIn: parent; name: "sync"; size: 16; color: Theme.onSurfaceVariant }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: statsPage.reload() }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingLg
                Layout.rightMargin: Theme.spacingLg
                columns: 4
                columnSpacing: Theme.spacingMd
                rowSpacing: Theme.spacingMd

                StatCard { Layout.fillWidth: true; icon: "stats"; label: qsTr("Total plays"); value: String(statsPage.stats.total_plays || 0) }
                StatCard { Layout.fillWidth: true; icon: "clock"; label: qsTr("Hours listened"); value: statsPage.formatHours(statsPage.stats.total_ms_played || 0) }
                StatCard { Layout.fillWidth: true; icon: "note"; label: qsTr("Unique tracks"); value: String(statsPage.stats.unique_tracks || 0) }
                StatCard { Layout.fillWidth: true; icon: "library"; label: qsTr("This week"); value: String(statsPage.stats.plays_this_week || 0) }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingLg
                Layout.rightMargin: Theme.spacingLg
                spacing: Theme.spacingSm
                visible: (statsPage.stats.hourly || []).length > 0

                Text { text: qsTr("Listening by hour of day"); color: Theme.onSurface; font: Theme.fontTitleLarge }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    radius: Theme.radiusMd
                    color: Theme.surfaceContainer

                    Row {
                        id: hourlyRow
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMd
                        spacing: 3

                        readonly property var hourly: statsPage.stats.hourly || []
                        readonly property real maxVal: {
                            var m = 1
                            for (var i = 0; i < hourly.length; i++) m = Math.max(m, hourly[i].count || 0)
                            return m
                        }

                        Repeater {
                            model: hourlyRow.hourly
                            delegate: Rectangle {
                                id: hourBar
                                required property var modelData
                                readonly property real frac: (modelData.count || 0) / hourlyRow.maxVal
                                width: (hourlyRow.width - 23 * 3) / 24
                                height: Math.max(2, frac * hourlyRow.height)
                                anchors.bottom: hourlyRow.bottom
                                radius: 2
                                color: Theme.primary
                                opacity: 0.55 + frac * 0.45
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingLg
                Layout.rightMargin: Theme.spacingLg
                Layout.bottomMargin: Theme.spacingLg
                spacing: Theme.spacingLg

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm
                    Text { text: qsTr("Top tracks"); color: Theme.onSurface; font: Theme.fontTitleLarge }
                    TrackList {
                        Layout.fillWidth: true
                        tracks: statsPage.stats.top_tracks || []
                        emptyMessage: qsTr("Play something to see your top tracks")
                        onPlayTrack: function(id) { Daemon.playTrack(id) }
                        onAddToQueue: function(id) { Daemon.addToQueue(id, false) }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm
                    Text { text: qsTr("Top artists"); color: Theme.onSurface; font: Theme.fontTitleLarge }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Repeater {
                            model: statsPage.stats.top_artists || []
                            delegate: RowLayout {
                                id: artistRow
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                spacing: Theme.spacingSm
                                Text { text: (artistRow.index + 1) + "."; color: Theme.onSurfaceVariant; font: Theme.fontMono; Layout.preferredWidth: 22 }
                                Text { Layout.fillWidth: true; text: artistRow.modelData.artist || ""; color: Theme.onSurface; font: Theme.fontBodyLarge; elide: Text.ElideRight }
                                Text { text: String(artistRow.modelData.count || 0); color: Theme.onSurfaceVariant; font: Theme.fontMono }
                            }
                        }
                        Text {
                            visible: (statsPage.stats.top_artists || []).length === 0
                            text: qsTr("No data yet")
                            color: Theme.onSurfaceVariant
                            font: Theme.fontBodyMedium
                        }
                    }
                }
            }
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
