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

    // --- lyrics ------------------------------------------------------------
    property bool showLyrics: false
    readonly property bool synced: daemon.lyricsStatus === "synced"
    readonly property bool hasLyrics: daemon.lyricsLines.length > 0

    // isled reports the position only when the track changes or is seeked, so
    // the highlight is counted on from there while the song plays.
    property double basePosition: 0
    property double baseTime: 0
    property double livePosition: 0

    Connections {
        target: daemon
        function onChanged() {
            page.basePosition = daemon.position;
            page.baseTime = Date.now();
            page.livePosition = daemon.position;
        }
    }

    Timer {
        interval: 200
        repeat: true
        running: page.showLyrics && daemon.playing
        onTriggered: {
            page.livePosition = page.basePosition + (Date.now() - page.baseTime) / 1000;
        }
    }

    readonly property int currentLine: {
        if (!page.synced)
            return -1;
        var ms = page.livePosition * 1000;
        var idx = -1;
        for (var i = 0; i < daemon.lyricsLines.length; i++) {
            if (daemon.lyricsLines[i].time <= ms)
                idx = i;
            else
                break;
        }
        return idx;
    }

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
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                visible: daemon.available
                text: daemon.artist !== "" ? daemon.artist : "Unknown artist"
                color: Qt.rgba(1, 1, 1, 0.62)
                font.pixelSize: 12
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                visible: daemon.album !== "" && daemon.available
                text: daemon.album
                color: Qt.rgba(1, 1, 1, 0.38)
                font.pixelSize: 11
            }
        }

        // --- controls ------------------------------------------------------
        Row {
            id: controls
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // Lyrics toggle
            Rectangle {
                height: 26
                width: 58
                radius: 13
                anchors.verticalCenter: parent.verticalCenter
                color: page.showLyrics ? Qt.rgba(1, 1, 1, 0.20)
                                       : (lyrTap.pressed ? Qt.rgba(1, 1, 1, 0.16)
                                                         : Qt.rgba(1, 1, 1, 0.07))

                Text {
                    anchors.centerIn: parent
                    text: "Lyrics"
                    color: page.showLyrics ? "white" : Qt.rgba(1, 1, 1, 0.7)
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }

                TapHandler {
                    id: lyrTap
                    onTapped: {
                        page.showLyrics = !page.showLyrics;
                        daemon.setLyricsEnabled(page.showLyrics);
                        if (page.showLyrics) {
                            page.basePosition = daemon.position;
                            page.baseTime = Date.now();
                        }
                    }
                }
            }

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
        font.pixelSize: 10
    }
    Text {
        x: page.width - page.padding - width
        y: 138
        visible: daemon.duration > 0
        text: page.formatTime(daemon.duration)
        color: Qt.rgba(1, 1, 1, 0.42)
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

    // --- the lyrics, over the page while shown ---------------------------------
    Item {
    id: lyricsView
    anchors.fill: parent
    visible: page.showLyrics
    opacity: page.showLyrics ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 160 } }

    // The song, small, above the lines.
    Text {
        id: lyricsTitle
        x: page.padding
        y: 8
        width: page.width - 2 * page.padding
        elide: Text.ElideRight
        text: daemon.title + (daemon.artist !== "" ? " \u2014 " + daemon.artist : "")
        color: Qt.rgba(1, 1, 1, 0.45)
        font.pixelSize: 10
    }

    ListView {
        id: lyricsList
        x: page.padding
        y: 26
        width: page.width - 2 * page.padding
        height: page.height - 34
        clip: true
        spacing: 6
        model: daemon.lyricsLines
        boundsBehavior: Flickable.StopAtBounds

        delegate: Text {
            width: lyricsList.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WrapAnywhere
            text: modelData.text
            color: index === page.currentLine ? "#ffffff" : Qt.rgba(1, 1, 1, 0.38)
            font.pixelSize: index === page.currentLine ? 15 : 12
            font.weight: index === page.currentLine ? Font.DemiBold : Font.Normal

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on font.pixelSize { NumberAnimation { duration: 180 } }

            TapHandler {
                enabled: page.synced
                onTapped: {
                    daemon.seekTo(modelData.time * 1000);
                    page.basePosition = modelData.time / 1000;
                    page.baseTime = Date.now();
                }
            }
        }
    }

    // Follow the sung line.
    onVisibleChanged: if (visible) Qt.callLater(lyricsView.followLine)
    Connections {
        target: page
        function onCurrentLineChanged() { lyricsView.followLine() }
    }

    function followLine() {
        if (!page.synced || page.currentLine < 0)
            return;
        var item = lyricsList.itemAtIndex(page.currentLine);
        if (item)
            lyricsList.positionViewAtIndex(page.currentLine, ListView.Center);
    }

    // What to say while there is nothing to sing.
    Text {
        anchors.centerIn: parent
        width: parent.width - 2 * page.padding
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        visible: !page.hasLyrics
        text: {
            switch (daemon.lyricsStatus) {
            case "loading": return "Looking for lyrics\u2026";
            case "not_found": return "No lyrics for this song";
            case "instrumental": return "Instrumental";
            case "error": return "Lyrics need a connection";
            case "none": return daemon.available ? "Lyrics" : "Nothing playing";
            default: return page.hasLyrics ? "" : "No lyrics";
            }
        }
        color: Qt.rgba(1, 1, 1, 0.35)
        font.pixelSize: 12
    }
}
}
