// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

// The Calendar & agenda page: month grid on the left, daily agenda on the right.
// Ported from gnome-extension/src/pages/calendar.js.

import QtQuick 2.15

Item {
    id: page

    readonly property real padding: 18

    // Selected and display date state
    property var selectedDate: new Date()
    property int displayYear: selectedDate.getFullYear()
    property int displayMonth: selectedDate.getMonth()

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    readonly property var dayHeaders: ["S", "M", "T", "W", "T", "F", "S"]

    function isSameDay(d1, d2) {
        return d1.getFullYear() === d2.getFullYear() &&
               d1.getMonth() === d2.getMonth() &&
               d1.getDate() === d2.getDate();
    }

    function isToday(d) {
        return isSameDay(d, new Date());
    }

    function formatDateKey(d) {
        var y = d.getFullYear();
        var m = (d.getMonth() + 1).toString().padStart(2, '0');
        var day = d.getDate().toString().padStart(2, '0');
        return y + "-" + m + "-" + day;
    }

    // Days grid for displayMonth
    property var monthGridDays: {
        var days = [];
        var firstDay = new Date(displayYear, displayMonth, 1);
        var startDayOfWeek = firstDay.getDay(); // 0 is Sunday
        var daysInMonth = new Date(displayYear, displayMonth + 1, 0).getDate();
        var daysInPrevMonth = new Date(displayYear, displayMonth, 0).getDate();

        // Previous month filler days
        for (var i = startDayOfWeek - 1; i >= 0; i--) {
            days.push({
                date: new Date(displayYear, displayMonth - 1, daysInPrevMonth - i),
                currentMonth: false
            });
        }
        // Current month days
        for (var d = 1; d <= daysInMonth; d++) {
            days.push({
                date: new Date(displayYear, displayMonth, d),
                currentMonth: true
            });
        }
        // Next month filler days up to 35 or 42
        var remaining = (7 - (days.length % 7)) % 7;
        for (var n = 1; n <= remaining; n++) {
            days.push({
                date: new Date(displayYear, displayMonth + 1, n),
                currentMonth: false
            });
        }
        return days;
    }

    Row {
        anchors.fill: parent
        anchors.margins: page.padding
        spacing: 20

        // ===================================================================
        // LEFT COLUMN: Mini Month Calendar Grid
        // ===================================================================
        Column {
            width: 220
            height: parent.height
            spacing: 8

            // Month navigation header
            Item {
                width: parent.width
                height: 24

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.monthNames[page.displayMonth] + " " + page.displayYear
                    color: "white"
                    font.pixelSize: 13
                    font.weight: Font.SemiBold
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Rectangle {
                        width: 22
                        height: 22
                        radius: 11
                        color: prevTap.pressed ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08)
                        Text { anchors.centerIn: parent; text: "\u2039"; color: "white"; font.pixelSize: 14 }
                        TapHandler {
                            id: prevTap
                            onTapped: {
                                if (page.displayMonth === 0) {
                                    page.displayMonth = 11;
                                    page.displayYear--;
                                } else {
                                    page.displayMonth--;
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 22
                        height: 22
                        radius: 11
                        color: nextTap.pressed ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08)
                        Text { anchors.centerIn: parent; text: "\u203A"; color: "white"; font.pixelSize: 14 }
                        TapHandler {
                            id: nextTap
                            onTapped: {
                                if (page.displayMonth === 11) {
                                    page.displayMonth = 0;
                                    page.displayYear++;
                                } else {
                                    page.displayMonth++;
                                }
                            }
                        }
                    }
                }
            }

            // Day of week headers (S M T W T F S)
            Grid {
                columns: 7
                width: parent.width
                spacing: 0

                Repeater {
                    model: page.dayHeaders
                    delegate: Item {
                        width: 220 / 7
                        height: 18
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: Qt.rgba(1, 1, 1, 0.4)
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            // 7x5 or 7x6 month date grid
            Grid {
                columns: 7
                width: parent.width
                spacing: 0

                Repeater {
                    model: page.monthGridDays

                    delegate: Item {
                        width: 220 / 7
                        height: 22

                        readonly property bool isSel: page.isSameDay(modelData.date, page.selectedDate)
                        readonly property bool isCurrentDay: page.isToday(modelData.date)

                        Rectangle {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            radius: 10
                            color: isSel ? "#38bdf8" : (isCurrentDay ? Qt.rgba(1, 1, 1, 0.16) : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: modelData.date.getDate()
                                color: isSel ? "black" : (modelData.currentMonth ? "white" : Qt.rgba(1, 1, 1, 0.25))
                                font.pixelSize: 11
                                font.weight: (isSel || isCurrentDay) ? Font.Bold : Font.Normal
                            }
                        }

                        TapHandler {
                            onTapped: {
                                page.selectedDate = modelData.date;
                                page.displayYear = modelData.date.getFullYear();
                                page.displayMonth = modelData.date.getMonth();
                            }
                        }
                    }
                }
            }
        }

        // Vertical divider line
        Rectangle {
            width: 1
            height: parent.height
            color: Qt.rgba(1, 1, 1, 0.1)
        }

        // ===================================================================
        // RIGHT COLUMN: Selected Day Agenda & Quick Add
        // ===================================================================
        Column {
            width: parent.width - 220 - 20 - 1
            height: parent.height
            spacing: 8

            // Day Agenda Header (e.g. Wednesday, 4 Nov)
            Item {
                width: parent.width
                height: 24

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDate(page.selectedDate, "dddd, d MMM")
                    color: "white"
                    font.pixelSize: 13
                    font.weight: Font.SemiBold
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48
                    height: 20
                    radius: 10
                    color: todayTap.pressed ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08)

                    Text {
                        anchors.centerIn: parent
                        text: "Today"
                        color: Qt.rgba(1, 1, 1, 0.8)
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }

                    TapHandler {
                        id: todayTap
                        onTapped: {
                            page.selectedDate = new Date();
                            page.displayYear = page.selectedDate.getFullYear();
                            page.displayMonth = page.selectedDate.getMonth();
                        }
                    }
                }
            }

            // Events List
            ListView {
                id: list
                width: parent.width
                height: parent.height - 24 - newEntry.height - 16
                clip: true
                spacing: 6

                model: {
                    var curKey = page.formatDateKey(page.selectedDate);
                    return daemon.events.filter(function(e) {
                        return e.date === curKey;
                    });
                }

                delegate: Rectangle {
                    width: list.width
                    height: 38
                    radius: 7
                    color: Qt.rgba(1, 1, 1, 0.06)

                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10

                        // Time pill
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 50
                            height: 22
                            radius: 5
                            color: Qt.rgba(14/255, 165/255, 233/255, 0.20)

                            Text {
                                anchors.centerIn: parent
                                text: modelData.start || "All day"
                                color: "#38bdf8"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                            }
                        }

                        // Event title
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 50 - 10 - 24
                            elide: Text.ElideRight
                            text: modelData.title
                            color: "white"
                            font.pixelSize: 12
                        }

                        // Remove
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u00D7"
                            color: delTap.pressed ? "white" : Qt.rgba(1, 1, 1, 0.35)
                            font.pixelSize: 15

                            TapHandler {
                                id: delTap
                                onTapped: daemon.calendarRemove(modelData.id)
                            }
                        }
                    }
                }

                // Empty state
                Text {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: "No events on this day"
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font.pixelSize: 12
                }
            }

            // Quick add event field
            Rectangle {
                id: newEntry
                width: parent.width
                height: 32
                radius: 7
                color: Qt.rgba(1, 1, 1, 0.07)

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: "white"
                    font.pixelSize: 11
                    selectByMouse: true

                    TapHandler { onTapped: backend.grabKeyboardFocus() }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: input.text === "" && !input.activeFocus
                        text: "Add event for this day (e.g. Sync at 15:00)\u2026"
                        color: Qt.rgba(1, 1, 1, 0.35)
                        font.pixelSize: 11
                    }

                    onAccepted: {
                        var val = text.trim();
                        if (val !== "") {
                            daemon.calendarAdd(page.formatDateKey(page.selectedDate), val);
                            text = "";
                        }
                    }
                }
            }
        }
    }
}
