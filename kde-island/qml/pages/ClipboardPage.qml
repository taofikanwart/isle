// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

// The Clipboard history page: search, pinned clips, click to copy.
// Ported from gnome-extension/src/pages/clips.js and shelf.js.

import QtQuick 2.15

Item {
    id: page

    readonly property real padding: 20
    property string searchQuery: ""
    property string feedback: ""

    Timer {
        id: feedbackTimer
        interval: 1800
        onTriggered: page.feedback = ""
    }

    Column {
        anchors.fill: parent
        anchors.margins: page.padding
        spacing: 10

        // --- header / search bar ------------------------------------------
        Row {
            width: parent.width
            height: 32
            spacing: 8

            Rectangle {
                width: parent.width - (clearBtn.visible ? clearBtn.width + 8 : 0)
                height: parent.height
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.07)

                TextInput {
                TapHandler { onTapped: backend.grabKeyboardFocus() }
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: "white"
                    font.pixelSize: 12
                    selectByMouse: true
                    onTextChanged: page.searchQuery = text.toLowerCase().trim()

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: searchInput.text === "" && !searchInput.activeFocus
                        text: "Search clipboard\u2026"
                        color: Qt.rgba(1, 1, 1, 0.35)
                        font.pixelSize: 12
                    }
                }
            }

            Rectangle {
                id: clearBtn
                visible: daemon.clips.length > 0
                width: 64
                height: parent.height
                radius: 8
                color: clearTap.pressed ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.07)

                Text {
                    anchors.centerIn: parent
                    text: "Clear all"
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.pixelSize: 11
                }

                TapHandler {
                    id: clearTap
                    onTapped: daemon.clipClear()
                }
            }
        }

        // Feedback alert banner if copied
        Rectangle {
            visible: page.feedback !== ""
            width: parent.width
            height: 24
            radius: 6
            color: "#15803d"

            Text {
                anchors.centerIn: parent
                text: page.feedback
                color: "white"
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }

        // --- clips list ----------------------------------------------------
        ListView {
            id: list
            width: parent.width
            height: parent.height - 42 - (page.feedback !== "" ? 34 : 0)
            clip: true
            spacing: 6
            model: {
                var all = daemon.clips;
                if (page.searchQuery === "") return all;
                return all.filter(function(c) {
                    return (c.preview || "").toLowerCase().indexOf(page.searchQuery) >= 0;
                });
            }

            delegate: Rectangle {
                id: itemRect
                width: list.width
                height: 44
                radius: 8
                color: itemTap.pressed ? Qt.rgba(1, 1, 1, 0.16)
                    : (itemHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))

                HoverHandler { id: itemHover }

                TapHandler {
                    id: itemTap
                    onTapped: {
                        daemon.clipCopy(modelData.preview);
                        page.feedback = "\u2713 Copied to clipboard!";
                        feedbackTimer.restart();
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10

                    // Badge kind
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        height: 22
                        radius: 5
                        color: modelData.kind === "link" ? "#0284c7" : Qt.rgba(1, 1, 1, 0.12)

                        Text {
                            anchors.centerIn: parent
                            text: modelData.kind === "link" ? "LINK" : "TEXT"
                            color: "white"
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }
                    }

                    // Content preview
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 38 - 10 - 54
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.WrapAnywhere
                        text: modelData.preview || ""
                        color: "white"
                        font.pixelSize: 12
                    }

                    // Right actions: Pin & Delete
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        // Pin
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            color: modelData.pinned ? Qt.rgba(234/255, 179/255, 8/255, 0.25)
                                                    : (pinTap.pressed ? Qt.rgba(1, 1, 1, 0.15) : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: modelData.pinned ? "\u2605" : "\u2606"
                                color: modelData.pinned ? "#facc15" : Qt.rgba(1, 1, 1, 0.45)
                                font.pixelSize: 13
                            }

                            TapHandler {
                                id: pinTap
                                onTapped: daemon.clipSetPinned(modelData.id, !modelData.pinned)
                            }
                        }

                        // Remove
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            color: delTap.pressed ? Qt.rgba(1, 1, 1, 0.2) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\u00D7"
                                color: Qt.rgba(1, 1, 1, 0.45)
                                font.pixelSize: 16
                            }

                            TapHandler {
                                id: delTap
                                onTapped: daemon.clipRemove(modelData.id)
                            }
                        }
                    }
                }
            }

            // Empty state
            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: page.searchQuery === "" ? "Clipboard history is empty" : "No matching clips"
                color: Qt.rgba(1, 1, 1, 0.35)
                font.pixelSize: 13
            }
        }
    }
}
