// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

// The Reminders page: a plain list where ticking one strikes it through and
// removes it, with a field at the bottom to add a new one. Ported from
// gnome-extension/src/pages/tasks.js.

import QtQuick 2.15

Item {
    id: page

    readonly property real padding: 24

    Column {
        anchors.fill: parent
        anchors.margins: page.padding
        spacing: 10

        // --- reminders list ------------------------------------------------
        ListView {
            id: list
            width: parent.width
            height: parent.height - newEntry.height - 10
            clip: true
            model: daemon.tasks

            delegate: Row {
                width: list.width
                height: 32
                spacing: 10

                // Checkbox
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    radius: 6
                    color: modelData.done ? "#22c55e" : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    border.color: modelData.done ? "#16a34a" : Qt.rgba(1, 1, 1, 0.18)

                    Text {
                        anchors.centerIn: parent
                        visible: modelData.done
                        text: "\u2713"
                        color: "white"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    TapHandler {
                        onTapped: daemon.todoSetDone(modelData.id, !modelData.done)
                    }
                }

                // Title
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 20 - 10 - 24
                    elide: Text.ElideRight
                    text: modelData.title
                    color: modelData.done ? Qt.rgba(1, 1, 1, 0.35) : "white"
                    font.family: "Inter Variable"
                    font.pixelSize: 13
                    font.strikeout: modelData.done
                }

                // Delete
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u00D7"
                    color: delTap.pressed ? "white" : Qt.rgba(1, 1, 1, 0.3)
                    font.pixelSize: 16

                    TapHandler {
                        id: delTap
                        onTapped: daemon.todoRemove(modelData.id)
                    }
                }
            }

            // Empty state
            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "No reminders"
                color: Qt.rgba(1, 1, 1, 0.35)
                font.family: "Inter Variable"
                font.pixelSize: 13
            }
        }

        // --- new reminder input --------------------------------------------
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
                    text: "New reminder\u2026"
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font.family: "Inter Variable"
                    font.pixelSize: 12
                }

                onAccepted: {
                    if (text.trim() !== "") {
                        daemon.todoAdd(text.trim());
                        text = "";
                    }
                }
            }
        }
    }
}
