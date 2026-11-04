// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

// The island itself: a notch hanging from the top edge, closed as a pill with
// the time, opening on hover into the pages. Sizes and radii are ported from
// gnome-extension/src/controller.js (COMPACT_*, EXPANDED_*) and compact.js
// (SIZES, PILL_HEIGHT).

import QtQuick 2.15
import Isle 1.0
import "Theme.js" as Theme

Item {
    id: root

    // --- theme -------------------------------------------------------------
    property string themeName: initialTheme
    property int tint: 0

    // --- ported constants --------------------------------------------------
    // Isle's default is the closed island *inside* the top bar, like a notch:
    // IN_BAR_RADIUS / IN_BAR_SHOULDER. Set ISLE_IN_BAR=0 to hang it below
    // the bar instead (COMPACT_RADIUS / COMPACT_SHOULDER + notch-depth).
    readonly property bool inBar: backend.inBar
    readonly property real compactRadius: inBar ? 10 : 16
    readonly property real compactShoulder: inBar ? 7 : 10
    readonly property real compactWidth: inBar ? 144 : 164
    readonly property real notchDepth: 30
    readonly property real expandedRadius: 32
    readonly property real expandedShoulder: 22
    readonly property real expandedWidth: 600
    readonly property real pageHeight: 150
    readonly property real bottomPadding: 20

    readonly property int topInset: backend.topInset
    // A playing song widens the closed island, as the clock alone does not
    // leave room for it.
    readonly property real closedWidth: compactWidth + (daemon.playing ? 140 : 0)
    // With no panel at the top there is no band to sit in; hang it instead.
    readonly property real closedHeight: (inBar && topInset > 0)
        ? topInset : topInset + notchDepth
    readonly property real openHeight: topInset + pageHeight + bottomPadding

    property bool open: hover.hovered

    // Drives the clock; a new Date each second so the text re-evaluates.
    property var now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    readonly property real progress: Math.max(0, Math.min(1,
        (springWidth.value - closedWidth) / Math.max(1, expandedWidth - closedWidth)))

    // --- springs -----------------------------------------------------------
    Spring {
        id: springWidth
        Component.onCompleted: reset(root.closedWidth)
        target: root.open ? root.expandedWidth : root.closedWidth
        onValueChanged: root.syncMask()
    }
    Spring {
        id: springHeight
        Component.onCompleted: reset(root.closedHeight)
        target: root.open ? root.openHeight : root.closedHeight
        onValueChanged: root.syncMask()
    }
    Spring {
        id: springRadius
        damping: 25
        Component.onCompleted: reset(root.compactRadius)
        target: root.open ? root.expandedRadius : root.compactRadius
    }
    Spring {
        id: springShoulder
        damping: 25
        Component.onCompleted: reset(root.compactShoulder)
        target: root.open ? root.expandedShoulder : root.compactShoulder
        onValueChanged: root.syncMask()
    }

    // --- the notch ---------------------------------------------------------
    NotchShape {
        id: notch
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        bodyWidth: springWidth.value
        bodyHeight: springHeight.value
        radius: springRadius.value
        shoulder: springShoulder.value
        themeName: root.themeName
        tint: root.tint

        HoverHandler { id: hover }
    }

    // Everything outside the notch passes clicks through; the expanded page
    // keeps its own band so it stays clickable.
    function syncMask() {
        if (!notch)
            return;
        backend.setInputMask(Math.round(notch.x), 0,
                             Math.round(notch.width), Math.round(notch.height));
    }
    onTopInsetChanged: syncMask()
    // Before the view sizes the root item, the notch has no place on screen;
    // the first real size is the one that matters.
    onWidthChanged: syncMask()
    onHeightChanged: syncMask()
    Component.onCompleted: {
        Theme.setTheme(root.themeName, root.tint);
        syncMask();
    }

    // --- content -----------------------------------------------------------
    // The body, shoulders excluded: the compact island fills it, the pages
    // start below the band the top bar occupies.
    Item {
        id: body
        x: notch.x + Math.max(0, springShoulder.value)
        y: 0
        width: Math.max(0, springWidth.value)
        height: Math.max(0, springHeight.value)
        clip: true

        // Closed: the time, and the song if one is playing.
        Item {
            id: compact
            anchors.fill: parent
            visible: root.progress < 0.5
            opacity: 1 - root.progress * 2

            Row {
                anchors.centerIn: parent
                spacing: 8

                Image {
                    visible: daemon.playing && daemon.artPath !== ""
                    source: daemon.artPath !== "" ? "file://" + daemon.artPath : ""
                    width: 20
                    height: 20
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Text {
                    text: Qt.formatTime(root.now, "hh:mm")
                    color: "white"
                    font.family: "Inter Variable"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                Text {
                    visible: daemon.playing
                    width: Math.max(0, Math.min(140, implicitWidth))
                    elide: Text.ElideRight
                    text: daemon.title !== "" ? daemon.title : "Playing"
                    color: "white"
                    opacity: 0.75
                    font.family: "Inter Variable"
                    font.pixelSize: 11
                }
            }
        }

        // The header, in the band the top bar occupies.
        Text {
            id: header
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(0, (root.topInset - height) / 2)
            visible: root.progress >= 0.5
            opacity: (root.progress - 0.5) * 2
            text: Qt.formatTime(root.now, "hh:mm")
            color: "white"
            font.family: "Inter Variable"
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        // Open: the pages, below the band the top bar occupies.
        Loader {
            x: 0
            y: root.topInset
            width: body.width
            height: Math.max(0, body.height - root.topInset)
            visible: root.progress >= 0.5
            opacity: (root.progress - 0.5) * 2
            source: "pages/MediaPage.qml"
            active: root.progress > 0.35
        }
    }
}
