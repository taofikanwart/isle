// SPDX-License-Identifier: GPL-3.0-or-later
// Feasibility spike for the KDE port of Isle. Throwaway code.
//
// A dummy notch: 220x34 at rest, springs open to 480x240 on hover. The
// root item is transparent and full window size; only `notch` is visible,
// and main.cpp masks input to it.

import QtQuick 2.15
import Isle.Spike 1.0

Item {
    id: rootItem

    // --- input mask, read by main.cpp -------------------------------------
    // A small margin keeps the mask slightly larger than the notch so the
    // pointer does not fall out mid-animation (hysteresis, criterion 3).
    readonly property real maskX: notch.x - 8
    readonly property real maskY: 0
    readonly property real maskWidth: notch.width + 16
    readonly property real maskHeight: notch.y + notch.height + 8
    signal maskChanged()

    // --- geometry ----------------------------------------------------------
    readonly property real closedW: 220
    readonly property real closedH: 34
    readonly property real openW: 480
    readonly property real openH: 240
    property bool open: hover.hovered

    Spring {
        id: widthSpring
        Component.onCompleted: reset(rootItem.closedW)
        target: rootItem.open ? rootItem.openW : rootItem.closedW
        onValueChanged: rootItem.maskChanged()
    }
    Spring {
        id: heightSpring
        Component.onCompleted: reset(rootItem.closedH)
        target: rootItem.open ? rootItem.openH : rootItem.closedH
    }
    // GENTLE config from spring.js: same speed, no overshoot, for radii.
    Spring {
        id: radiusSpring
        stiffness: 155
        damping: 25
        Component.onCompleted: reset(17)
        target: rootItem.open ? 28 : 17
    }

    // --- the notch ----------------------------------------------------------
    Rectangle {
        id: notch
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: widthSpring.value
        height: heightSpring.value
        radius: radiusSpring.value
        // Criterion 4: glass without KWin blur. A near-black translucent
        // fill over a subtle vertical sheen reads as glass on any wallpaper.
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.13, 0.13, 0.15, 0.92) }
            GradientStop { position: 1.0; color: Qt.rgba(0.04, 0.04, 0.05, 0.96) }
        }
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.09)

        HoverHandler { id: hover }

        // Closed: a clock placeholder.
        Text {
            anchors.centerIn: parent
            visible: !rootItem.open
            text: Qt.formatTime(new Date(), "hh:mm")
            color: "white"
            font.pixelSize: 15
        }

        // Open: media page placeholder wired to isled (criterion 5).
        Column {
            anchors.centerIn: parent
            spacing: 14
            visible: rootItem.open
            opacity: (widthSpring.value - rootItem.closedW) /
                     (rootItem.openW - rootItem.closedW)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: layerShellActive ? "layer-shell \u2713" : "X11 fallback"
                color: layerShellActive ? "#8f8" : "#fc6"
                font.pixelSize: 12
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: rootItem.openW - 64
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: daemon.connected ? daemon.nowPlaying : "isled: offline"
                color: daemon.connected ? "white" : "#f88"
                font.pixelSize: 14
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 110
                height: 36
                radius: 18
                color: playTap.pressed ? Qt.rgba(1, 1, 1, 0.25)
                                       : Qt.rgba(1, 1, 1, 0.12)
                Text {
                    anchors.centerIn: parent
                    text: "\u25B6\u2759\u2759"
                    color: "white"
                }
                TapHandler {
                    id: playTap
                    onTapped: daemon.playPause()
                }
            }
        }
    }
}
