// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

// The Calendar & agenda page: upcoming meetings, start times, quick add.
// Ported from gnome-extension/src/pages/calendar.js.

import QtQuick 2.15

Item {
    id: page

    readonly property real padding: 20

    Column {
        anchors.fill: parent
        anchors.margins: page.padding
        spacing: 10

        // --- events list ---------------------------------------------------
        ListView {
            id: list
            width: parent.width
            height: parent.height - newEntry.height - 10
            clip: true
            spacing: 8
            model: daemon.events

            delegate: Rectangle {
                width: list.width
                height: 48
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.05)

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    // Time badge / pill
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 58
                        height: 26
                        radius: 6
                        color: Qt.rgba(14/255, 165/255, 233/255, 0.20)
                        border.width: 1
                        border.color: Qt.rgba(56/255, 189/255, 248/255, 0.35)

                        Text {
                            anchors.centerIn: parent
                            text: modelData.start || "All day"
                            color: "#38bdf8"
                            font.family: "Inter Variable"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                    }

                    // Event details
                    Column {
                        width: parent.width - 58 - 12 - 24
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: modelData.title
                            color: "white"
                            font.family: "Inter Variable"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                        Text {
                            text: modelData.date
                            color: Qt.rgba(1, 1, 1, 0.45)
                            font.family: "Inter Variable"
                            font.pixelSize: 10
                        }
                    }

                    // Delete event
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u00D7"
                        color: delTap.pressed ? "white" : Qt.rgba(1, 1, 1, 0.35)
                        font.pixelSize: 16

                        TapHandler {
                            id: delTap
                            onTapped: daemon.calendarRemove(modelData.id)
                        }
                    }
                }
            }

            // Empty state
            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "No upcoming events"
                color: Qt.rgba(1, 1, 1, 0.35)
                font.family: "Inter Variable"
                font.pixelSize: 13
            }
        }

        // --- quick add bar -------------------------------------------------
        Rectangle {
            id: newEntry
            width: parent.width
            height: 34
            radius: 8
            color: Qt.rgba(1, 1, 1, 0.06)

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                color: "white"
                font.family: "Inter Variable"
                font.pixelSize: 12
                selectByMouse: true

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: input.text === "" && !input.activeFocus
                    text: "Add event (e.g. Sync meeting at 15:00)\u2026"
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font.family: "Inter Variable"
                    font.pixelSize: 12
                }

                onAccepted: {
                    var val = text.trim();
                    if (val !== "") {
                        var today = Qt.formatDate(new Date(), "yyyy-MM-dd");
                        daemon.calendarAdd(today, val);
                        text = "";
                    }
                }
            }
        }
    }
}
