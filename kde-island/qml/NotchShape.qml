// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

// The island's outline: a body with rounded bottom corners that flares out
// at the top edge through two shoulders, the way a notch meets the screen.
// Geometry is ported from gnome-extension/src/glass.js (the ShapeMask shader)
// and island.js `_box`.
//
// The canvas keeps the expanded size and the body is drawn inside it, centred
// and pinned to the top. Resizing a Canvas reallocates its backing texture,
// which once per frame is what made the hover stutter.

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

    // The largest the notch ever gets (expanded tall plus its overshoot);
    // the canvas never resizes, and every pixel it holds is cleared and
    // painted on each frame of an animation.
    readonly property real roomWidth: 600 + 2 * 22
    readonly property real roomHeight: 240

    implicitWidth: roomWidth
    implicitHeight: roomHeight

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
            var bodyWidth = Math.max(0, shape.bodyWidth);
            var bodyHeight = Math.max(0, shape.bodyHeight);
            var r = Math.min(shape.radius, bodyWidth / 2, bodyHeight);

            // Centred, pinned to the top: the body grows out from the middle.
            var left = Math.round((shape.width - bodyWidth) / 2);
            var right = left + bodyWidth;
            var bottom = bodyHeight;

            ctx.beginPath();
            ctx.moveTo(left - s, 0);
            if (s > 0)
                ctx.arc(left - s, s, s, -Math.PI / 2, 0, false);
            ctx.lineTo(left, bottom - r);
            ctx.arcTo(left, bottom, left + r, bottom, r);
            ctx.lineTo(right - r, bottom);
            ctx.arcTo(right, bottom, right, bottom - r, r);
            ctx.lineTo(right, s);
            if (s > 0)
                ctx.arc(right + s, s, s, Math.PI, Math.PI * 1.5, false);
            ctx.closePath();

            // No drop shadow: the island is flush with the top edge, and a
            // blurred shadow here costs a CPU blur on every animation frame.
            ctx.fillStyle = Theme.css(Theme.fill());
            ctx.fill();

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
