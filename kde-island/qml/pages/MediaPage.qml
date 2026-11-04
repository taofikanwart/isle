// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

// The media page: cover, what is playing, and the controls isled already
// exposes over MPRIS. An early slice of gnome-extension/src/pages/media.js.

import QtQuick 2.15
import ".."

Item {
    id: page

    readonly property real padding: 24
    readonly property bool hasArt: daemon.artPath !== ""
    readonly property real progressPosition: daemon.duration > 0
        ? Math.max(0, Math.min(1, daemon.position / daemon.duration)) : 0

    // --- the song ----------------------------------------------------------
    Row {
        id: header
        x: page.padding
        y: 18
        width: page.width - 2 * page.padding
        spacing: 16

        Rectangle {
            width: 96
            height: 96
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.07)
            clip: true

            Image {
                anchors.fill: parent
                source: page.hasArt ? "file://" + daemon.artPath : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: page.hasArt
            }
            Text {
                anchors.centerIn: parent
                visible: !page.hasArt
                text: daemon.available ? "" : "\u2014"
                color: Qt.rgba(1, 1, 1, 0.35)
                font.pixelSize: 28
            }
            Icon {
                anchors.centerIn: parent
                visible: !page.hasArt && daemon.available
                kind: "note"
                color: Qt.rgba(1, 1, 1, 0.3)
                width: 34
                height: 34
            }
        }

        Column {
            width: parent.width - 96 - 16 - controls.width - 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: daemon.available
                    ? (daemon.title !== "" ? daemon.title : "Untitled")
                    : "Nothing playing"
                color: "white"
                font.family: "Inter Variable"
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                visible: daemon.available
                text: daemon.artist !== "" ? daemon.artist : "Unknown artist"
                color: Qt.rgba(1, 1, 1, 0.62)
                font.family: "Inter Variable"
                font.pixelSize: 12
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                visible: daemon.album !== "" && daemon.available
                text: daemon.album
                color: Qt.rgba(1, 1, 1, 0.38)
                font.family: "Inter Variable"
                font.pixelSize: 11
            }
        }

        // --- controls ------------------------------------------------------
        Row {
            id: controls
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: [
                    {glyph: "previous", tip: "Previous", on: daemon.canGoPrevious,
                     call: "previous"},
                    {glyph: daemon.playing ? "pause" : "play", tip: "Play/Pause",
                     on: daemon.canPlayPause, call: "playPause"},
                    {glyph: "next", tip: "Next", on: daemon.canGoNext,
                     call: "next"},
                ]

                delegate: Rectangle {
                    width: modelData.call === "playPause" ? 42 : 34
                    height: width
                    radius: width / 2
                    color: tap.pressed ? Qt.rgba(1, 1, 1, 0.22)
                        : (modelData.call === "playPause" ? Qt.rgba(1, 1, 1, 0.13)
                                                          : Qt.rgba(1, 1, 1, 0.06))
                    opacity: modelData.on ? 1 : 0.35

                    Icon {
                        anchors.centerIn: parent
                        kind: modelData.glyph
                        color: "white"
                        width: modelData.call === "playPause" ? 15 : 12
                        height: width
                    }

                    TapHandler {
                        id: tap
                        enabled: modelData.on
                        onTapped: daemon[modelData.call]()
                    }
                }
            }
        }
    }

    // --- progress ----------------------------------------------------------
    Rectangle {
        x: page.padding
        y: 128
        width: page.width - 2 * page.padding
        height: 3
        radius: 1.5
        color: Qt.rgba(1, 1, 1, 0.12)

        Rectangle {
            width: parent.width * page.progressPosition
            height: parent.height
            radius: 1.5
            color: Qt.rgba(1, 1, 1, 0.85)
            Behavior on width { SmoothedAnimation { duration: 240 } }
        }
    }

    Text {
        x: page.padding
        y: 138
        text: page.formatTime(daemon.position)
        color: Qt.rgba(1, 1, 1, 0.42)
        font.family: "Inter Variable"
        font.pixelSize: 10
    }
    Text {
        x: page.width - page.padding - width
        y: 138
        visible: daemon.duration > 0
        text: page.formatTime(daemon.duration)
        color: Qt.rgba(1, 1, 1, 0.42)
        font.family: "Inter Variable"
        font.pixelSize: 10
    }

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            seconds = 0;
        var total = Math.floor(seconds);
        var minutes = Math.floor(total / 60);
        var rest = total % 60;
        return minutes + ":" + (rest < 10 ? "0" : "") + rest;
    }
}
