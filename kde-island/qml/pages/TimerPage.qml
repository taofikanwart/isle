// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

// The Pomodoro timer page: a ring showing the time left in the current phase,
// Start/Pause and Reset buttons, and today's completed session count.
// Ported from gnome-extension/src/pages/timer.js.

import QtQuick 2.15
import ".."

Item {
    id: page

    readonly property real padding: 24
    readonly property real ringSize: 104
    readonly property real progress: daemon.pomodoroDuration > 0
        ? Math.max(0, Math.min(1, 1 - daemon.pomodoroRemaining / daemon.pomodoroDuration))
        : 0

    // Local countdown ticker while running, so the seconds tick smoothly
    // without flooding D-Bus.
    Timer {
        interval: 250
        running: daemon.pomodoroRunning
        repeat: true
        onTriggered: page.displaySeconds = daemon.pomodoroRemaining
    }
    property double displaySeconds: daemon.pomodoroRemaining
    Connections {
        target: daemon
        function onPomodoroChanged() { page.displaySeconds = daemon.pomodoroRemaining }
    }

    readonly property color phaseColor: {
        switch (daemon.pomodoroPhase) {
        case "short_break":
        case "long_break":
            return "#4ade80"; // green
        default:
            return "#f97316"; // orange
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 36

        // --- the ring ------------------------------------------------------
        Item {
            width: page.ringSize
            height: page.ringSize

            Canvas {
                id: ringCanvas
                anchors.fill: parent

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var cx = width / 2;
                    var cy = height / 2;
                    var r = (Math.min(width, height) - 8) / 2;

                    // Track
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, Math.PI * 2);
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.12);
                    ctx.lineWidth = 5;
                    ctx.stroke();

                    // Progress
                    if (page.progress > 0) {
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, -Math.PI / 2,
                                -Math.PI / 2 + Math.PI * 2 * page.progress);
                        ctx.strokeStyle = page.phaseColor;
                        ctx.lineWidth = 5;
                        ctx.lineCap = "round";
                        ctx.stroke();
                    }
                }

                Connections {
                    target: page
                    function onProgressChanged() { ringCanvas.requestPaint() }
                    function onPhaseColorChanged() { ringCanvas.requestPaint() }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: page.formatMinutes(page.displaySeconds)
                    color: "white"
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: page.phaseLabel(daemon.pomodoroPhase)
                    color: Qt.rgba(1, 1, 1, 0.5)
                    font.pixelSize: 11
                }
            }
        }

        // --- controls ------------------------------------------------------
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Row {
                spacing: 8

                // Start / Pause
                Rectangle {
                    width: 100
                    height: 38
                    radius: 19
                    color: startTap.pressed ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.14)

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            kind: daemon.pomodoroRunning ? "pause" : "play"
                            color: "white"
                            width: 12
                            height: 12
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: daemon.pomodoroRunning ? "Pause"
                                : (daemon.pomodoroPhase === "idle" ? "Start" : "Resume")
                            color: "white"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                    }

                    TapHandler {
                        id: startTap
                        onTapped: daemon.pomodoroToggle()
                    }
                }

                // Reset (Stop)
                Rectangle {
                    visible: daemon.pomodoroPhase !== "idle"
                    width: 38
                    height: 38
                    radius: 19
                    color: stopTap.pressed ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)

                    Text {
                        anchors.centerIn: parent
                        text: "\u25A0"
                        color: "white"
                        font.pixelSize: 12
                    }

                    TapHandler {
                        id: stopTap
                        onTapped: daemon.pomodoroStop()
                    }
                }

                // Skip
                Rectangle {
                    visible: daemon.pomodoroPhase !== "idle"
                    width: 38
                    height: 38
                    radius: 19
                    color: skipTap.pressed ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)

                    Icon {
                        anchors.centerIn: parent
                        kind: "next"
                        color: "white"
                        width: 11
                        height: 11
                    }

                    TapHandler {
                        id: skipTap
                        onTapped: daemon.pomodoroSkip()
                    }
                }
            }

            Text {
                text: daemon.pomodoroSessions > 0
                    ? daemon.pomodoroSessions + " session" + (daemon.pomodoroSessions > 1 ? "s" : "") + " today"
                    : "No sessions today"
                color: Qt.rgba(1, 1, 1, 0.4)
                font.pixelSize: 11
            }
        }
    }

    function formatMinutes(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            seconds = 0;
        var total = Math.ceil(seconds);
        var m = Math.floor(total / 60);
        var s = total % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function phaseLabel(phase) {
        switch (phase) {
        case "work": return "Focus";
        case "short_break": return "Short break";
        case "long_break": return "Long break";
        default: return "Focus";
        }
    }
}
