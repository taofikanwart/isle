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

    // Opened by the pointer resting on the notch. Where the global pointer can
    // be read (X11) a poll decides, because changing the window's shape makes
    // X send a leave and hover events alone would drop it mid-animation. On
    // Wayland the handler is all there is.
    property bool pointerIn: false
    property bool open: backend.pointerQueryable ? pointerIn : hover.hovered

    Timer {
        interval: 50
        running: backend.pointerQueryable
        repeat: true
        onTriggered: root.pollPointer()
    }

    function pollPointer() {
        if (!backend.pointerQueryable)
            return;
        // A few pixels of slack, so the edge is not a razor: the pointer may
        // leave the drawn shape by a hair without closing it.
        var margin = 6;
        var body = open ? expandedWidth : closedWidth;
        var height = open ? openHeight : closedHeight;
        var shoulder = open ? expandedShoulder : compactShoulder;
        var total = Math.round(body + 2 * shoulder);
        var x = Math.round((root.width - total) / 2);
        root.pointerIn = backend.pointerInside(x - margin, 0,
                                               total + 2 * margin, Math.round(height + margin));
    }

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
    // Stepped from the render loop (main.cpp calls advanceIsland), so the
    // motion is measured in painted frames rather than timer ticks.
    Spring {
        id: springWidth
        drivenByFrames: true
        onWake: backend.requestFrame()
        Component.onCompleted: reset(root.closedWidth)
        target: root.open ? root.expandedWidth : root.closedWidth
    }
    Spring {
        id: springHeight
        drivenByFrames: true
        onWake: backend.requestFrame()
        Component.onCompleted: reset(root.closedHeight)
        target: root.open ? root.openHeight : root.closedHeight
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
    }

    Connections {
        target: frames
        function onTicked(dt) { root.advanceIsland(dt) }
    }

    function advanceIsland(dt) {
        springWidth.advance(dt);
        springHeight.advance(dt);
        springRadius.advance(dt);
        springShoulder.advance(dt);
    }

    // --- the notch ---------------------------------------------------------
    NotchShape {
        id: notch
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: roomWidth
        height: roomHeight
        bodyWidth: springWidth.value
        bodyHeight: springHeight.value
        radius: springRadius.value
        shoulder: springShoulder.value
        themeName: root.themeName
        tint: root.tint
    }

    // The pointer follows the state's size, not the frame's: a region that
    // shrinks under the pointer would make it leave and the island flicker.
    Item {
        id: hoverArea
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: open ? expandedWidth : closedWidth
        height: open ? openHeight : closedHeight

        HoverHandler { id: hover }
    }

    // Everything outside the notch passes clicks through; the expanded page
    // keeps its own band so it stays clickable.
    //
    // Only transitions change the mask, not every spring frame: on X11 each
    // change is a synchronous shape update, and one per frame is what made
    // the hover stutter. During a transition the mask is the target's band,
    // which is a superset of the island at any point in it, so nothing the
    // island draws is ever cut.
    property bool maskExpanded: false

    function applyMask(expanded) {
        var bodyWidth = expanded ? root.expandedWidth : root.closedWidth;
        var bodyHeight = expanded ? root.openHeight : root.closedHeight;
        var shoulder = expanded ? root.expandedShoulder : root.compactShoulder;
        var total = Math.round(bodyWidth + 2 * shoulder);
        backend.setInputMask(Math.round((root.width - total) / 2), 0,
                             total, Math.round(bodyHeight));
        root.maskExpanded = expanded;
    }

    // A close keeps the wide mask until the island has shrunk back into it.
    Timer {
        id: shrink
        interval: 620
        onTriggered: root.applyMask(false)
    }

    onOpenChanged: {
        if (open) {
            shrink.stop();
            applyMask(true);
        } else {
            shrink.restart();
        }
    }
    // Before the view sizes the root item, the notch has no place on screen;
    // the first real size is the one that matters.
    onWidthChanged: applyMask(root.maskExpanded)
    onTopInsetChanged: applyMask(root.maskExpanded)
    // The closed island widens for a song.
    onClosedWidthChanged: {
        if (!open && !shrink.running)
            applyMask(false);
    }
    Component.onCompleted: {
        Theme.setTheme(root.themeName, root.tint);
        applyMask(false);
    }

    // --- content -----------------------------------------------------------
    // The body, shoulders excluded: the compact island fills it, the pages
    // start below the band the top bar occupies.
    Item {
        id: body
        x: Math.round((root.width - Math.max(0, springWidth.value)) / 2)
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

        // Active page index
        property int pageIndex: 0
        readonly property var pageSources: [
            "pages/MediaPage.qml",
            "pages/TimerPage.qml",
            "pages/TasksPage.qml",
        ]

        // --- header row: tabs on the left, clock centered -----------------
        Item {
            id: headerRow
            x: 18
            y: 0
            width: body.width - 36
            height: root.topInset
            visible: root.progress >= 0.5
            opacity: (root.progress - 0.5) * 2

            // Tabs
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: [
                        { label: "Music", idx: 0 },
                        { label: "Timer", idx: 1 },
                        { label: "Tasks", idx: 2 },
                    ]

                    delegate: Rectangle {
                        width: tabText.implicitWidth + 14
                        height: 22
                        radius: 11
                        color: body.pageIndex === modelData.idx
                            ? Qt.rgba(1, 1, 1, 0.16)
                            : (tabTap.pressed ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

                        Text {
                            id: tabText
                            anchors.centerIn: parent
                            text: modelData.label
                            color: body.pageIndex === modelData.idx
                                ? "white"
                                : Qt.rgba(1, 1, 1, 0.55)
                            font.family: "Inter Variable"
                            font.pixelSize: 11
                            font.weight: body.pageIndex === modelData.idx
                                ? Font.Medium : Font.Normal
                        }

                        TapHandler {
                            id: tabTap
                            onTapped: body.pageIndex = modelData.idx
                        }
                    }
                }
            }

            // The clock, perfectly centered in the notch
            Text {
                anchors.centerIn: parent
                text: Qt.formatTime(root.now, "hh:mm")
                color: "white"
                font.family: "Inter Variable"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
        }

        // Open: the active page, below the band the top bar occupies.
        Loader {
            x: 0
            y: root.topInset
            width: body.width
            height: Math.max(0, body.height - root.topInset)
            visible: root.progress >= 0.5
            opacity: (root.progress - 0.5) * 2
            source: body.pageSources[body.pageIndex]
            active: root.progress > 0.35
        }
    }
}
