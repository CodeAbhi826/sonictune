// pages/SettingsAppearancePage.qml — appearance + performance sub-page.

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "../theme"
import "../components"
import "../router"

Item {
    id: page
    objectName: "settingsAppearance"

    property string pageTitle: qsTr("Appearance")

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.space4

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.space2
            Layout.rightMargin: Theme.space2
            Layout.topMargin: Theme.space2
            spacing: Theme.space2

            IconButton {
                iconName: "chevronLeft"
                iconSize: 18
                toolTip: qsTr("Back")
                onClicked: Router.popPage()
            }

            Text {
                Layout.fillWidth: true
                text: page.pageTitle
                color: Theme.fgSurface
                font: Theme.fontHeadlineSmall
                elide: Text.ElideRight
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                id: column
                width: page.width
                spacing: Theme.space3
                anchors.leftMargin: Theme.space4
                anchors.rightMargin: Theme.space4

                Repeater {
                    model: [
                        { key: "reducedMotion", label: qsTr("Reduced motion"), desc: qsTr("Disable animations and transitions") },
                        { key: "lowEndMode", label: qsTr("Low-end mode"), desc: qsTr("Disable shadows, limit heavy effects") },
                        { key: "disableShadows", label: qsTr("Disable shadows"), desc: qsTr("Drop all drop shadows") },
                        { key: "disableImageCache", label: qsTr("Disable image cache"), desc: qsTr("Don't cache artwork thumbnails") },
                        { key: "smoothScrolling", label: qsTr("Smooth scrolling"), desc: qsTr("Enable momentum on lists") }
                    ]
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        radius: Theme.radiusMd
                        color: Theme.surfaceContainer

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.space4
                            spacing: Theme.space3

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    text: row.modelData.label
                                    color: Theme.fgSurface
                                    font: Theme.fontBodyMedium
                                }
                                Text {
                                    text: row.modelData.desc
                                    color: Theme.fgSurfaceVariant
                                    font: Theme.fontBodySmall
                                }
                            }

                            Switch {
                                checked: {
                                    var k = row.modelData.key
                                    return k === "reducedMotion" ? Theme.reducedMotion
                                        : k === "lowEndMode" ? Theme.lowEndMode
                                        : k === "disableShadows" ? Theme.disableShadows
                                        : k === "disableImageCache" ? Theme.disableImageCache
                                        : Theme.smoothScrolling
                                }
                                Material.accent: Theme.primary
                                onToggled: {
                                    var k = row.modelData.key
                                    if (k === "reducedMotion") Theme.reducedMotion = checked
                                    else if (k === "lowEndMode") Theme.lowEndMode = checked
                                    else if (k === "disableShadows") Theme.disableShadows = checked
                                    else if (k === "disableImageCache") Theme.disableImageCache = checked
                                    else Theme.smoothScrolling = checked
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.topMargin: Theme.space2
                    text: qsTr("Image source size")
                    color: Theme.fgSurface
                    font: Theme.fontBodyMedium
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Artwork resolution used by the image cache")
                        color: Theme.fgSurfaceVariant
                        font: Theme.fontBodySmall
                    }
                    Text {
                        text: String(Theme.imageSourceSize) + "px"
                        color: Theme.fgSurfaceVariant
                        font: Theme.fontMono
                    }
                }
                STSlider {
                    Layout.fillWidth: true
                    from: 128
                    to: 1024
                    stepSize: 32
                    value: Theme.imageSourceSize
                    onMoved: Theme.imageSourceSize = Math.round(value)
                }

                Text {
                    Layout.topMargin: Theme.space2
                    text: qsTr("List cache buffer")
                    color: Theme.fgSurface
                    font: Theme.fontBodyMedium
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("How far lists pre-render beyond the viewport")
                        color: Theme.fgSurfaceVariant
                        font: Theme.fontBodySmall
                    }
                    Text {
                        text: String(Theme.listCacheBuffer) + "px"
                        color: Theme.fgSurfaceVariant
                        font: Theme.fontMono
                    }
                }
                STSlider {
                    Layout.fillWidth: true
                    from: 0
                    to: 500
                    stepSize: 10
                    value: Theme.listCacheBuffer
                    onMoved: Theme.listCacheBuffer = Math.round(value)
                }

                Item { Layout.preferredHeight: Theme.space4 }
            }
        }
    }
}
