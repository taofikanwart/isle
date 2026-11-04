// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

// The island's outline: a body with rounded bottom corners that flares out
// at the top edge through two shoulders, the way a notch meets the screen.
// Geometry is ported from gnome-extension/src/glass.js (the ShapeMask shader)
// and island.js `_box`.

import QtQuick 2.15
import "Theme.js" as Theme

Item {
    id: shape

    property real bodyWidth: 164
    property real bodyHeight: 30
    property real radius: 16
    property real shoulder: 10

    // Theme changes reach the canvas through these.
    property string themeName: "black"
    property int tint: 0

    width: bodyWidth + 2 * Math.max(0, shoulder)
    height: bodyHeight

    onBodyWidthChanged: canvas.requestPaint()
    onBodyHeightChanged: canvas.requestPaint()
    onRadiusChanged: canvas.requestPaint()
    onShoulderChanged: canvas.requestPaint()
    onThemeNameChanged: canvas.requestPaint()
    onTintChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();

            var s = Math.max(0, shape.shoulder);
            var r = Math.min(shape.radius, shape.bodyWidth / 2, shape.bodyHeight);
            var left = s;
            var right = s + shape.bodyWidth;
            var bottom = shape.bodyHeight;

            ctx.beginPath();
            ctx.moveTo(0, 0);
            if (s > 0)
                ctx.arc(0, s, s, -Math.PI / 2, 0, false);
            ctx.lineTo(left, bottom - r);
            ctx.arcTo(left, bottom, left + r, bottom, r);
            ctx.lineTo(right - r, bottom);
            ctx.arcTo(right, bottom, right, bottom - r, r);
            ctx.lineTo(right, s);
            if (s > 0)
                ctx.arc(right + s, s, s, Math.PI, Math.PI * 1.5, false);
            ctx.closePath();

            // The fill, with a soft shadow so the island sits above whatever
            // it covers.
            ctx.save();
            ctx.shadowColor = "rgba(0,0,0,0.45)";
            ctx.shadowBlur = 18;
            ctx.shadowOffsetY = 6;
            ctx.fillStyle = Theme.css(Theme.fill());
            ctx.fill();
            ctx.restore();

            // A sheen: light from above, fading out over the body.
            var sheen = ctx.createLinearGradient(0, 0, 0, bottom);
            sheen.addColorStop(0, "rgba(255,255,255,0.09)");
            sheen.addColorStop(0.55, "rgba(255,255,255,0)");
            ctx.fillStyle = sheen;
            ctx.fill();

            // The rim, lit from above (theme.js `edge`).
            if (Theme.edge()) {
                var rim = ctx.createLinearGradient(0, 0, 0, bottom);
                rim.addColorStop(0, Theme.edgeCss("top"));
                rim.addColorStop(1, Theme.edgeCss("bottom"));
                ctx.strokeStyle = rim;
                ctx.lineWidth = 1;
                ctx.stroke();
            }
        }
    }
}
