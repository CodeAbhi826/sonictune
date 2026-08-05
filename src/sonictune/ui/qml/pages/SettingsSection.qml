// pages/SettingsSection.qml — collapsible Material 3 settings section.
// A 56px header row (icon + title + rotating chevron) toggles a content
// column that animates open/closed. SettingsPage listens to expandRequested
// to enforce single-open behavior across all sections.

import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"

Rectangle {
    id: section
    color: Theme.surfaceContainerLow
    radius: Theme.radiusMd

    property string title: ""
    property string icon: ""
    property bool initiallyExpanded: false
    property bool expanded: initiallyExpanded

    signal expandRequested()

    default property alias content: contentColumn.children

    implicitWidth: 320
    implicitHeight: 56 + (section.expanded ? contentColumn.implicitHeight + Theme.space4 : 0)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 56

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space4
                anchors.rightMargin: Theme.space4
                spacing: Theme.space3

                Icon {
                    name: section.icon
                    size: 20
                    color: section.expanded ? Theme.primary : Theme.fgSurfaceVariant
                    Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.durFast } }
                }

                Text {
                    Layout.fillWidth: true
                    text: section.title
                    color: Theme.fgSurface
                    font: Theme.fontTitleMedium
                    elide: Text.ElideRight
                }

                Icon {
                    name: "chevronDown"
                    size: 20
                    color: Theme.fgSurfaceVariant
                    rotation: section.expanded ? 180 : 0
                    Behavior on rotation {
                        enabled: !Theme.reducedMotion
                        NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    section.expanded = !section.expanded
                    section.expandRequested()
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: section.expanded ? contentColumn.implicitHeight : 0
            clip: true
            Behavior on Layout.preferredHeight {
                enabled: !Theme.reducedMotion
                NumberAnimation {
                    duration: Theme.durNormal
                    easing.type: Easing.OutCubic
                }
            }

            ColumnLayout {
                id: contentColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: Theme.space4
                anchors.rightMargin: Theme.space4
                spacing: Theme.space4
            }
        }
    }
}
