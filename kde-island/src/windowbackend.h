// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

#pragma once

#include <QObject>
#include <QRegion>
#include <QWindow>

// Where the island's window sits and what part of it takes clicks. The two
// sessions need different machinery, so the rest of the app only ever sees
// this interface: on Wayland the window is a layer-shell surface pinned to
// the top edge; on X11 it is an unmanaged, always-on-top window.
//
// The window is always as big as the expanded island. Everything outside the
// notch is masked away so clicks reach whatever is underneath.
class WindowBackend : public QObject {
    Q_OBJECT
    // How far the panel pushes the usable screen down at the top edge.
    Q_PROPERTY(int topInset READ topInset NOTIFY insetChanged)
    Q_PROPERTY(quintptr windowId READ windowId CONSTANT)
    // Whether the global pointer can be read: true on X11, not on Wayland.
    Q_PROPERTY(bool pointerQueryable READ pointerQueryable CONSTANT)

public:
    explicit WindowBackend(QWindow *window, QObject *parent = nullptr);

    // Called once, before the window is shown.
    void attach();

    int topInset() const { return m_topInset; }
    quintptr windowId() const;
    bool pointerQueryable() const { return m_pointerQueryable; }

    // Whether the pointer is inside a rectangle of the window. Used for the
    // open/close test: a shape-mask change makes X send a spurious leave, so
    // hover events alone cannot be trusted to keep the island open.
    Q_INVOKABLE bool pointerInside(int x, int y, int width, int height) const;

    bool layerShell() const { return m_layerShell; }

    // The island's shape in window coordinates; everything outside passes
    // clicks through. Called every frame while the island animates.
    Q_INVOKABLE void setInputMask(int x, int y, int width, int height);
    // Asks for one more frame; the frame clock only ticks when one is painted.
    Q_INVOKABLE void requestFrame();

    // Forces keyboard focus onto this window (X11 override-redirect workaround)
    Q_INVOKABLE void grabKeyboardFocus();

signals:
    void insetChanged();

private:
    void measureInset();

    QWindow *m_window;
    QRegion m_mask;
    int m_topInset = 0;
    bool m_pointerQueryable = false;
    bool m_layerShell = false;
};
