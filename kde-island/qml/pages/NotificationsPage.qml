// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

// The Notifications page: recent notifications, app icons, dismiss buttons.
// Ported from gnome-extension/src/pages/notifications.js.

import QtQuick 2.15

Item {
    id: page

    readonly property real padding: 20

    Column {
        anchors.fill: parent
        anchors.margins: page.padding
        spacing: 10

        // --- header row ---------------------------------------------------
        Row {
            width: parent.width
            height: 24

            Text {
                text: "Recent notifications"
                color: Qt.rgba(1, 1, 1, 0.5)
                font.pixelSize: 12
                font.weight: Font.Medium
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Do Not Disturb: no banner on the closed notch while on.
                Rectangle {
                    width: 76
                    height: 22
                    radius: 6
                    color: daemon.doNotDisturb ? Qt.rgba(56/255, 189/255, 248/255, 0.25)
                        : (dndTap.pressed ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08))
                    border.width: 1
                    border.color: daemon.doNotDisturb ? Qt.rgba(56/255, 189/255, 248/255, 0.5)
                                                      : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: daemon.doNotDisturb ? "DND on" : "DND off"
                        color: daemon.doNotDisturb ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.7)
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }

                    TapHandler {
                        id: dndTap
                        onTapped: daemon.doNotDisturb = !daemon.doNotDisturb
                    }
                }

                Rectangle {
                    visible: daemon.notifications.length > 0
                    width: 60
                    height: 22
                    radius: 6
                    color: clearTap.pressed ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08)

                    Text {
                        anchors.centerIn: parent
                        text: "Clear all"
                        color: Qt.rgba(1, 1, 1, 0.7)
                        font.pixelSize: 11
                    }

                    TapHandler {
                        id: clearTap
                        onTapped: daemon.notificationClearAll()
                    }
                }
            }
        }

        // --- notifications list --------------------------------------------
        ListView {
            id: list
            width: parent.width
            height: parent.height - 34
            clip: true
            spacing: 8
            model: daemon.notifications

            delegate: Rectangle {
                width: list.width
                height: Math.max(52, col.implicitHeight + 16)
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.06)

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Column {
                        id: col
                        width: parent.width - 24
                        spacing: 3

                        Row {
                            spacing: 8
                            // App name badge
                            Rectangle {
                                width: appText.implicitWidth + 8
                                height: 18
                                radius: 4
                                color: Qt.rgba(1, 1, 1, 0.12)

                                Text {
                                    id: appText
                                    anchors.centerIn: parent
                                    text: modelData.app || "App"
                                    color: Qt.rgba(1, 1, 1, 0.85)
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }
                            }

                            Text {
                                text: modelData.time || ""
                                color: Qt.rgba(1, 1, 1, 0.35)
                                font.pixelSize: 10
                            }
                        }

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: modelData.summary || ""
                            color: "white"
                            font.pixelSize: 12
                            font.weight: Font.SemiBold
                        }

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WrapAnywhere
                            text: modelData.body || ""
                            color: Qt.rgba(1, 1, 1, 0.65)
                            font.pixelSize: 11
                        }
                    }

                    // Dismiss
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u00D7"
                        color: delTap.pressed ? "white" : Qt.rgba(1, 1, 1, 0.35)
                        font.pixelSize: 16

                        TapHandler {
                            id: delTap
                            onTapped: daemon.notificationDismiss(index)
                        }
                    }
                }
            }

            // Empty state
            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "No new notifications"
                color: Qt.rgba(1, 1, 1, 0.35)
                font.pixelSize: 13
            }
        }
    }
}
