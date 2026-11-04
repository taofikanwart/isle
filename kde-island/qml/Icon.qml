// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

// Playback glyphs drawn as paths, not text: the emoji fonts a desktop
// installs happily claim U+25B6 and friends and paint them in colour.

import QtQuick 2.15

Item {
    id: icon

    property string kind: "play"
    property color color: "white"

    implicitWidth: 14
    implicitHeight: 14

    onKindChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var size = Math.min(icon.width, icon.height);
            ctx.translate((icon.width - size) / 2, (icon.height - size) / 2);
            ctx.scale(size / 16, size / 16);
            ctx.fillStyle = icon.color;

            function triangle(x1, y1, x2, y2, x3, y3) {
                ctx.beginPath();
                ctx.moveTo(x1, y1);
                ctx.lineTo(x2, y2);
                ctx.lineTo(x3, y3);
                ctx.closePath();
                ctx.fill();
            }

            switch (icon.kind) {
            case "play":
                triangle(5, 2.5, 13.5, 8, 5, 13.5);
                break;
            case "pause":
                ctx.fillRect(4.5, 3, 2.6, 10);
                ctx.fillRect(8.9, 3, 2.6, 10);
                break;
            case "previous":
                ctx.fillRect(2.5, 3, 2.2, 10);
                triangle(13.5, 2.5, 5, 8, 13.5, 13.5);
                break;
            case "next":
                triangle(2.5, 2.5, 11, 8, 2.5, 13.5);
                ctx.fillRect(11.3, 3, 2.2, 10);
                break;
            case "note":
                ctx.beginPath();
                ctx.arc(6, 11.5, 2.6, 0, Math.PI * 2);
                ctx.fill();
                ctx.fillRect(7.6, 3.5, 1.6, 8);
                ctx.beginPath();
                ctx.moveTo(7.6, 3.5);
                ctx.quadraticCurveTo(11.5, 4.2, 11.5, 6.4);
                ctx.quadraticCurveTo(10.2, 4.8, 7.6, 5.1);
                ctx.closePath();
                ctx.fill();
                break;
            }
        }
    }
}
