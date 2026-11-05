// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

// The Settings (Pengaturan) page: theme, tint, notch depth, placement.
// Settings are persisted in ~/.config/isle/island.conf via QSettings.

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: page

    readonly property real padding: 20

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: innerCol.implicitHeight + 2 * page.padding
        clip: true

        Column {
            id: innerCol
            x: page.padding
            width: parent.width - 2 * page.padding
            spacing: 12

        // --- Theme selector ------------------------------------------------
        Item {
            width: parent.width
            height: 32

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Island theme"
                color: "white"
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Black
                Rectangle {
                    width: 70
                    height: 28
                    radius: 14
                    color: daemon.themeName === "black" ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.07)
                    border.width: 1
                    border.color: daemon.themeName === "black" ? Qt.rgba(1, 1, 1, 0.3) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "Black"
                        color: "white"
                        font.pixelSize: 12
                        font.weight: daemon.themeName === "black" ? Font.DemiBold : Font.Normal
                    }

                    TapHandler {
                        onTapped: daemon.themeName = "black"
                    }
                }

                // Glass
                Rectangle {
                    width: 70
                    height: 28
                    radius: 14
                    color: daemon.themeName === "glass" ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.07)
                    border.width: 1
                    border.color: daemon.themeName === "glass" ? Qt.rgba(1, 1, 1, 0.3) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "Glass"
                        color: "white"
                        font.pixelSize: 12
                        font.weight: daemon.themeName === "glass" ? Font.DemiBold : Font.Normal
                    }

                    TapHandler {
                        onTapped: daemon.themeName = "glass"
                    }
                }
            }
        }

        // --- Glass tint (only active when glass) ---------------------------
        Item {
            visible: daemon.themeName === "glass"
            width: parent.width
            height: 28

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Glass dark tint"
                color: Qt.rgba(1, 1, 1, 0.8)
                font.pixelSize: 12
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: minusTap.pressed ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08)
                    Text { anchors.centerIn: parent; text: "\u2212"; color: "white"; font.pixelSize: 13 }
                    TapHandler { id: minusTap; onTapped: daemon.glassTint = Math.max(0, daemon.glassTint - 10) }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    horizontalAlignment: Text.AlignHCenter
                    text: daemon.glassTint + "%"
                    color: "white"
                    font.pixelSize: 12
                }

                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: plusTap.pressed ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08)
                    Text { anchors.centerIn: parent; text: "+"; color: "white"; font.pixelSize: 13 }
                    TapHandler { id: plusTap; onTapped: daemon.glassTint = Math.min(100, daemon.glassTint + 10) }
                }
            }
        }

        // --- Placement: Inside top bar vs Hanging --------------------------
        Item {
            width: parent.width
            height: 32

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Closed island position"
                color: "white"
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 140
                height: 28
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.10)

                Text {
                    anchors.centerIn: parent
                    text: daemon.inBar ? "Inside top bar" : "Hanging below"
                    color: "white"
                    font.pixelSize: 12
                }

                TapHandler {
                    onTapped: daemon.inBar = !daemon.inBar
                }
            }
        }

        // --- Notch depth ---------------------------------------------------
        Item {
            visible: !daemon.inBar
            width: parent.width
            height: 28

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Notch depth (height)"
                color: Qt.rgba(1, 1, 1, 0.8)
                font.pixelSize: 12
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: dMinusTap.pressed ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08)
                    Text { anchors.centerIn: parent; text: "\u2212"; color: "white"; font.pixelSize: 13 }
                    TapHandler { id: dMinusTap; onTapped: daemon.notchDepth = Math.max(20, daemon.notchDepth - 2) }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    horizontalAlignment: Text.AlignHCenter
                    text: daemon.notchDepth + " px"
                    color: "white"
                    font.pixelSize: 12
                }

                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: dPlusTap.pressed ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08)
                    Text { anchors.centerIn: parent; text: "+"; color: "white"; font.pixelSize: 13 }
                    TapHandler { id: dPlusTap; onTapped: daemon.notchDepth = Math.min(50, daemon.notchDepth + 2) }
                }
            }
        }


        // --- Display (monitor) -------------------------------------------------
        Item {
            width: parent.width
            height: 32

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Display (monitor)"
                color: "white"
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            ComboBox {
                id: displayCombo
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 160
                height: 28
                model: backend.screenNames
                currentIndex: daemon.monitorIndex
                onActivated: {
                    daemon.monitorIndex = currentIndex;
                    backend.setTargetScreen(daemon.monitorIndex);
                }

                background: Rectangle {
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.10)
                }
                contentItem: Text {
                    leftPadding: 12
                    verticalAlignment: Text.AlignVCenter
                    text: displayCombo.displayText
                    color: "white"
                    font.pixelSize: 12
                }
            }
        }

        // Footer info
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Isle for KDE Plasma \u2022 Config saved to ~/.config/isle/island.conf"
            color: Qt.rgba(1, 1, 1, 0.3)
            font.pixelSize: 10
        }
    }
}
