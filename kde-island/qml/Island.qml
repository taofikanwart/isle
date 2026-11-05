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
            backend.setTargetScreen(daemon.monitorIndex);
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
            // While Do Not Disturb is on the notch keeps still; the entry
            // still goes into the list and the badge still lights.
            if (!root.open && !daemon.doNotDisturb) {
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
    // Held open by the global shortcut for a few seconds, wherever the pointer is.
    property bool forcedOpen: false
    property bool open: forcedOpen || (backend.pointerQueryable ? pointerIn : hover.hovered)

    Timer {
        id: forcedTimer
        interval: 8000
        onTriggered: root.forcedOpen = false
    }

    Connections {
        target: hotkey
        function onClipsRequested() {
            // Tab order: Music 0, Notifications 1, Timer 2, Reminders 3,
            // Shelf (clipboard) 4, Calendar 5, Settings 6.
            body.pageIndex = 4;
            root.forcedOpen = true;
            forcedTimer.restart();
        }
    }

    Timer {
        interval: 50
        running: backend.pointerQueryable
        repeat: true
        onTriggered: root.pollPointer()
    }

    function pollPointer() {
        if (!backend.pointerQueryable)
            return;
        // Generous margin when open (16px bottom and sides), so moving between tabs
        // never accidentally triggers an outside-pointer close.
        var marginX = open ? 16 : 6;
        var marginY = open ? 20 : 6;
        var body = open ? expandedWidth : closedWidth;
        var height = open ? openHeight : closedHeight;
        var shoulder = open ? expandedShoulder : compactShoulder;
        var total = Math.round(body + 2 * shoulder);
        var x = Math.round((root.width - total) / 2);
        root.pointerIn = backend.pointerInside(x - marginX, 0,
                                               total + 2 * marginX, Math.round(height + marginY));
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
        backend.setTargetScreen(daemon.monitorIndex);
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

            // Banner alert view (clock stays visible to the right)
            Row {
                anchors.centerIn: parent
                visible: root.bannerAlert
                spacing: 8

                Rectangle {
                    width: 10; height: 10; radius: 5
                    color: "#38bdf8"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.bannerApp + ":"
                    color: Qt.rgba(1, 1, 1, 0.7)
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, Math.min(160, implicitWidth))
                    elide: Text.ElideRight
                    text: root.bannerSummary
                    color: "white"
                    font.pixelSize: 11
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatTime(root.now, "hh:mm")
                    color: Qt.rgba(1, 1, 1, 0.4)
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
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
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Active page index
        // Tabs in GNOME Isle order:
        // 0: Music (isle-music)
        // 1: Notifications (isle-bell)
        // 2: Timer (isle-timer)
        // 3: Reminders (isle-tasks)
        // 4: Shelf (isle-shelf)
        // 5: Calendar (isle-calendar)
        // 6: Settings (isle-settings)
        property int pageIndex: 0
        readonly property var pageSources: [
            "pages/MediaPage.qml",
            "pages/NotificationsPage.qml",
            "pages/TimerPage.qml",
            "pages/TasksPage.qml",
            "pages/ClipboardPage.qml",
            "pages/CalendarPage.qml",
            "pages/SettingsPage.qml",
        ]

        // --- header row: tabs on the left, clock & date on the right
        Item {
            id: headerRow
            x: 16
            y: 0
            width: body.width - 32
            height: root.topInset
            visible: root.progress >= 0.5
            opacity: (root.progress - 0.5) * 2

            // Tabs matching GNOME Isle's TABS and style (.isle-tab)
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    model: [
                        { name: "music", label: "Music", icon: "isle-music", idx: 0 },
                        { name: "notifications", label: "Notifications", icon: "isle-bell", idx: 1, badge: daemon.unreadNotificationsCount },
                        { name: "focus", label: "Timer", icon: "isle-timer", idx: 2 },
                        { name: "reminders", label: "Reminders", icon: "isle-tasks", idx: 3 },
                        { name: "shelf", label: "Shelf", icon: "isle-shelf", idx: 4 },
                        { name: "calendar", label: "Calendar", icon: "isle-calendar", idx: 5 },
                    ]

                    delegate: Rectangle {
                        id: tabItem
                        readonly property bool isCurrent: body.pageIndex === modelData.idx
                        readonly property bool isHovered: tabHover.hovered

                        height: 24
                        // Animated expansion: active tab shows icon + label; inactive shows icon only
                        width: isCurrent ? (tabContent.implicitWidth + 16) : 28
                        radius: 999 // pill shape (.isle-tab)
                        color: isCurrent ? Qt.rgba(1, 1, 1, 0.10)
                            : (isHovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent")

                        Behavior on width {
                            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                        }

                        HoverHandler { id: tabHover }

                        Row {
                            id: tabContent
                            anchors.centerIn: parent
                            spacing: 6

                            // Tab SVG Icon (outline when inactive, filled when active)
                            Item {
                                width: 15
                                height: 15
                                anchors.verticalCenter: parent.verticalCenter

                                Image {
                                    anchors.fill: parent
                                    // Some SVGs use complex mask IDs that QSVG may render as solid boxes.
                                    // The outline SVG is always clean and crisp.
                                    source: "qrc:/icons/" + modelData.icon + ".svg"
                                    fillMode: Image.PreserveAspectFit
                                    sourceSize.width: 15
                                    sourceSize.height: 15
                                    opacity: tabItem.isCurrent ? 1.0 : (tabItem.isHovered ? 0.78 : 0.55)
                                }

                                // Red notification dot badge (.isle-tab-badge: #ff453a)
                                Rectangle {
                                    visible: modelData.badge !== undefined && modelData.badge > 0
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: "#ff453a"
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.topMargin: -1
                                    anchors.rightMargin: -1
                                }
                            }

                            // Active tab label (hidden when tab is inactive)
                            Text {
                                visible: tabItem.isCurrent
                                text: modelData.label
                                color: "#ffffff"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        TapHandler {
                            onTapped: body.pageIndex = modelData.idx
                        }
                    }
                }
            }

            // Right header group: Clock + Settings gear button
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                // The date, beside the clock when the island is open.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDate(root.now, "dd MMM yyyy")
                    color: Qt.rgba(1, 1, 1, 0.55)
                    font.pixelSize: 11
                }

                // Header Clock matching GNOME Isle's (.isle-header-time)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatTime(root.now, "hh:mm")
                    color: Qt.rgba(1, 1, 1, 0.9)
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                // Settings icon matching GNOME Isle (.isle-header-settings: isle-settings.svg)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    radius: 12
                    color: body.pageIndex === 6
                        ? Qt.rgba(1, 1, 1, 0.16)
                        : (gearHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

                    HoverHandler { id: gearHover }

                    Image {
                        anchors.centerIn: parent
                        width: 15
                        height: 15
                        source: "qrc:/icons/isle-settings.svg"
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 15
                        sourceSize.height: 15
                        opacity: body.pageIndex === 6 ? 1.0 : (gearHover.hovered ? 0.9 : 0.6)
                    }

                    TapHandler {
                        onTapped: body.pageIndex = (body.pageIndex === 6 ? 0 : 6)
                    }
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
