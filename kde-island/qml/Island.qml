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

    // --- theme & settings --------------------------------------------------
    property string themeName: daemon.themeName
    property int tint: daemon.glassTint

    Connections {
        target: daemon
        function onSettingsChanged() {
            Theme.setTheme(daemon.themeName, daemon.glassTint);
            notch.themeName = daemon.themeName;
            notch.tint = daemon.glassTint;
        }
    }

    // --- ported constants --------------------------------------------------
    readonly property bool inBar: daemon.inBar
    readonly property real compactRadius: inBar ? 10 : 16
    readonly property real compactShoulder: inBar ? 7 : 10
    readonly property real compactWidth: inBar ? 144 : 164
    readonly property real notchDepth: daemon.notchDepth
    readonly property real expandedRadius: 32
    readonly property real expandedShoulder: 22
    readonly property real expandedWidth: 600
    readonly property real pageHeight: 150
    readonly property real bottomPadding: 20

    readonly property int topInset: backend.topInset

    // Notification banner alert state (when notch is closed)
    property bool bannerAlert: false
    property string bannerSummary: ""
    property string bannerApp: ""

    Timer {
        id: bannerTimer
        interval: 3800
        onTriggered: root.bannerAlert = false
    }

    Connections {
        target: daemon
        function onNotificationArrived(summary, body, app) {
            if (!root.open) {
                root.bannerSummary = summary;
                root.bannerApp = app;
                root.bannerAlert = true;
                bannerTimer.restart();
            }
        }
    }

    // A playing song or running pomodoro or banner alert widens the closed island.
    readonly property real closedWidth: bannerAlert ? 280
        : (compactWidth + (daemon.playing ? 140 : 0) + (daemon.pomodoroRunning ? 40 : 0))
    readonly property real closedHeight: (inBar && topInset > 0)
        ? topInset : topInset + notchDepth
    readonly property real openHeight: topInset + pageHeight + bottomPadding

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

    Item {
        id: hoverArea
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: open ? expandedWidth : closedWidth
        height: open ? openHeight : closedHeight

        HoverHandler { id: hover }
    }

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
    onWidthChanged: applyMask(root.maskExpanded)
    onTopInsetChanged: applyMask(root.maskExpanded)
    onClosedWidthChanged: {
        if (!open && !shrink.running)
            applyMask(false);
    }
    Component.onCompleted: {
        Theme.setTheme(root.themeName, root.tint);
        applyMask(false);
    }

    // --- content -----------------------------------------------------------
    Item {
        id: body
        x: Math.round((root.width - Math.max(0, springWidth.value)) / 2)
        y: 0
        width: Math.max(0, springWidth.value)
        height: Math.max(0, springHeight.value)
        clip: true

        // Closed: the time, activity icons, or banner alert
        Item {
            id: compact
            anchors.fill: parent
            visible: root.progress < 0.5
            opacity: 1 - root.progress * 2

            // Banner alert view
            Row {
                anchors.centerIn: parent
                visible: root.bannerAlert
                spacing: 8

                Rectangle {
                    width: 14
                    height: 14
                    radius: 7
                    color: "#38bdf8"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.bannerApp + ":"
                    color: Qt.rgba(1, 1, 1, 0.7)
                    font.family: "Inter Variable"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, Math.min(180, implicitWidth))
                    elide: Text.ElideRight
                    text: root.bannerSummary
                    color: "white"
                    font.family: "Inter Variable"
                    font.pixelSize: 11
                }
            }

            // Normal compact row
            Row {
                anchors.centerIn: parent
                visible: !root.bannerAlert
                spacing: 8

                // Pomodoro mini indicator
                Rectangle {
                    visible: daemon.pomodoroRunning
                    width: 12
                    height: 12
                    radius: 6
                    color: "#f97316"
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Music art
                Image {
                    visible: daemon.playing && daemon.artPath !== ""
                    source: daemon.artPath !== "" ? "file://" + daemon.artPath : ""
                    width: 18
                    height: 18
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Clock
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatTime(root.now, "hh:mm")
                    color: "white"
                    font.family: "Inter Variable"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                // Music title
                Text {
                    visible: daemon.playing
                    width: Math.max(0, Math.min(130, implicitWidth))
                    elide: Text.ElideRight
                    text: daemon.title !== "" ? daemon.title : "Playing"
                    color: "white"
                    opacity: 0.75
                    font.family: "Inter Variable"
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Active page index
        property int pageIndex: 0
        readonly property var pageSources: [
            "pages/MediaPage.qml",
            "pages/TimerPage.qml",
            "pages/TasksPage.qml",
            "pages/ClipboardPage.qml",
            "pages/CalendarPage.qml",
            "pages/NotificationsPage.qml",
            "pages/SettingsPage.qml",
        ]

        // --- header row: tabs on the left, clock centered, settings on the right
        Item {
            id: headerRow
            x: 16
            y: 0
            width: body.width - 32
            height: root.topInset
            visible: root.progress >= 0.5
            opacity: (root.progress - 0.5) * 2

            // Tabs
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Repeater {
                    model: [
                        { label: "Music", idx: 0 },
                        { label: "Timer", idx: 1 },
                        { label: "Tasks", idx: 2 },
                        { label: "Clips", idx: 3 },
                        { label: "Cal", idx: 4 },
                        { label: "Notifs", idx: 5, badge: daemon.unreadNotificationsCount },
                    ]

                    delegate: Rectangle {
                        width: tabContent.implicitWidth + 12
                        height: 22
                        radius: 11
                        color: body.pageIndex === modelData.idx
                            ? Qt.rgba(1, 1, 1, 0.16)
                            : (tabTap.pressed ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

                        Row {
                            id: tabContent
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: modelData.label
                                color: body.pageIndex === modelData.idx
                                    ? "white"
                                    : Qt.rgba(1, 1, 1, 0.55)
                                font.family: "Inter Variable"
                                font.pixelSize: 11
                                font.weight: body.pageIndex === modelData.idx
                                    ? Font.Medium : Font.Normal
                            }

                            // Notification badge dot
                            Rectangle {
                                visible: modelData.badge !== undefined && modelData.badge > 0
                                width: 5
                                height: 5
                                radius: 2.5
                                color: "#38bdf8"
                                anchors.verticalCenter: parent.verticalCenter
                            }
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

            // Settings button (gear ⚙) on the right
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                radius: 12
                color: body.pageIndex === 6
                    ? Qt.rgba(1, 1, 1, 0.20)
                    : (gearTap.pressed ? Qt.rgba(1, 1, 1, 0.12) : "transparent")

                Text {
                    anchors.centerIn: parent
                    text: "\u2699"
                    color: body.pageIndex === 6 ? "white" : Qt.rgba(1, 1, 1, 0.55)
                    font.pixelSize: 14
                }

                TapHandler {
                    id: gearTap
                    onTapped: body.pageIndex = (body.pageIndex === 6 ? 0 : 6)
                }
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
