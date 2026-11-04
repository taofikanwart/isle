// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

// The island's look. Port of gnome-extension/src/theme.js: Isle's own black,
// or glass over what is behind it, with a tint from 0 (clear) to 100 (dark).
// Colours are [r, g, b] / [r, g, b, a] in 0..1 so QML can build them itself.

var LOOKS = {
    black: { fill: [0, 0, 0, 1], solid: [0, 0, 0], edge: null },
    glass: {
        fill: [0.06, 0.068, 0.09, 0.45],
        solid: [0.085, 0.09, 0.11],
        edge: { top: 0.13, bottom: 0.05 },
    },
};

// Glass at its darkest (tint 100): dark smoked glass, as GNOME's blurred
// menus look.
var DARK_GLASS = {
    fill: [0.02, 0.025, 0.03, 0.3],
    solid: [0.06, 0.07, 0.07],
    edge: { top: 0.07, bottom: 0.04 },
};

var current = 'black';
var tinted = LOOKS.glass;
var tintValue = 0;

function mix(a, b, t) {
    return a + (b - a) * t;
}

function setTheme(name, tint) {
    current = LOOKS.hasOwnProperty(name) ? name : 'black';
    tintValue = Math.min(1, Math.max(0, (tint || 0) / 100));
    // Not one blend: the smoke's grey comes early and the sheen goes early,
    // the backdrop's tone late, so along the slider the glass only ever greys
    // and settles.
    var early = Math.sqrt(tintValue);
    var clear = LOOKS.glass;
    var dark = DARK_GLASS;
    tinted = {
        fill: [
            mix(clear.fill[0], dark.fill[0], early),
            mix(clear.fill[1], dark.fill[1], early),
            mix(clear.fill[2], dark.fill[2], early),
            mix(clear.fill[3], dark.fill[3], tintValue),
        ],
        solid: [
            mix(clear.solid[0], dark.solid[0], early),
            mix(clear.solid[1], dark.solid[1], early),
            mix(clear.solid[2], dark.solid[2], early),
        ],
        edge: {
            top: mix(clear.edge.top, dark.edge.top, tintValue),
            bottom: mix(clear.edge.bottom, dark.edge.bottom, tintValue),
        },
    };
}

function look() {
    return current === 'glass' ? tinted : LOOKS[current];
}

function translucent() {
    return current === 'glass';
}

function fill() {
    return look().fill;
}

function solid() {
    return look().solid;
}

function edge() {
    return look().edge;
}

// A signal colour (green, red, orange...) lifted a quarter towards white on
// glass, whose lighter grey would dull it.
function semantic(rgb) {
    if (current === 'black')
        return rgb;
    return rgb.map(function (c) { return c + (1 - c) * 0.25; });
}

// QML colour strings, so the Canvas and the items agree.
function css(rgba) {
    return 'rgba(' + Math.round(rgba[0] * 255) + ',' +
        Math.round(rgba[1] * 255) + ',' + Math.round(rgba[2] * 255) + ',' +
        (rgba.length > 3 ? rgba[3] : 1) + ')';
}

function edgeCss(which) {
    var e = edge();
    return e ? 'rgba(255,255,255,' + (which === 'top' ? e.top : e.bottom) + ')' : 'transparent';
}

function solidCss() {
    var s = solid();
    return css([s[0], s[1], s[2], 1]);
}
