// components/SyncedLyricsView.qml — synchronized lyrics view (Material 3 Dark).
// Smoothly scrolls and highlights the current line as the track plays.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Item {
    id: root
    
    property alias model: lyricsList.model
    property int currentPositionMs: 0
    property string currentTrackTitle: ""
    property string currentTrackArtist: ""
    property string currentTrackAlbum: ""
    property int currentTrackDurationMs: 0
    
    // --- Header with track info -------------------------------------------
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 80
        color: Qt.rgba(0, 0, 0, 0.4)
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.space4
            spacing: Theme.space4
            
            // Album art
            Rectangle {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                radius: Theme.radiusMd
                color: Theme.surfaceContainer
                clip: true
                
                Image {
                    anchors.fill: parent
                    source: ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                
                Icon {
                    anchors.centerIn: parent
                    name: "album"
                    size: 24
                    color: Theme.onSurfaceVariant
                }
            }
            
            // Track info
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                
                Text {
                    Layout.fillWidth: true
                    text: root.currentTrackTitle || qsTr("Unknown track")
                    color: Theme.onSurface
                    font: Theme.fontTitleLarge
                    elide: Text.ElideRight
                }
                
                Text {
                    Layout.fillWidth: true
                    text: root.currentTrackArtist || qsTr("Unknown artist")
                    color: Theme.onSurfaceVariant
                    font: Theme.fontBodyMedium
                    elide: Text.ElideRight
                }
                
                Text {
                    Layout.fillWidth: true
                    text: root.currentTrackAlbum || ""
                    color: Theme.onSurfaceVariant
                    font: Theme.fontBodySmall
                    elide: Text.ElideRight
                }
            }
        }
    }
    
    // --- Lyrics list ------------------------------------------------------
    ListView {
        id: lyricsList
        anchors.top: parent.top
        anchors.topMargin: 80  // header height
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        
        // Smooth scrolling behavior
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 1200
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: parent.height / 2 - 60
        preferredHighlightEnd: parent.height / 2 + 60
        
        // Model: list of {time_ms: number, text: string}
        model: []
        
        delegate: Item {
            id: lyricLine
            required property var modelData
            required property int index
            
            width: lyricsList.width
            height: 60
            
            property bool isActive: modelData.time_ms <= root.currentPositionMs &&
                                   (index === lyricsList.count - 1 || 
                                    lyricsList.model[index + 1].time_ms > root.currentPositionMs)
            
            // Highlight effect for active line
            Rectangle {
                anchors.fill: parent
                color: lyricLine.isActive ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : "transparent"
                visible: lyricLine.isActive
            }
            
            Text {
                anchors.centerIn: parent
                text: lyricLine.modelData.text || ""
                color: lyricLine.isActive ? Theme.primary : Theme.onSurface
                font: lyricLine.isActive ? Theme.fontTitleMedium : Theme.fontBodyLarge
                horizontalAlignment: Text.AlignHCenter
                width: parent.width - Theme.space8
                wrapMode: Text.Wrap
                
                // Smooth transitions
                Behavior on color {
                    enabled: !Theme.reducedMotion
                    ColorAnimation { duration: Theme.durFast }
                }
                Behavior on font.weight {
                    enabled: !Theme.reducedMotion
                    NumberAnimation { duration: Theme.durFast }
                }
            }
            
        }
    }

    // Auto-scroll to current line
    function onCurrentPositionMsChanged() {
        const list = lyricsList.model
        for (let i = 0; i < list.length; i++) {
            const current = list[i]
            const next = list[i + 1]
            if (current.time_ms <= root.currentPositionMs &&
                (!next || next.time_ms > root.currentPositionMs)) {
                if (lyricsList.currentIndex !== i) {
                    lyricsList.currentIndex = i
                }
                break
            }
        }
    }
    
    // --- Empty state ------------------------------------------------------
    Rectangle {
        id: emptyState
        anchors.fill: parent
        visible: lyricsList.model.length === 0
        color: Qt.rgba(0, 0, 0, 0)
        
        ColumnLayout {
            anchors.centerIn: parent
            spacing: Theme.space4
            
            Icon {
                Layout.alignment: Qt.AlignHCenter
                name: "lyrics"
                size: 48
                color: Theme.onSurfaceVariant
            }
            
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("No lyrics available")
                color: Theme.onSurface
                font: Theme.fontTitleLarge
            }
            
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Lyrics will appear here when available")
                color: Theme.onSurfaceVariant
                font: Theme.fontBodyMedium
                width: 300
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}