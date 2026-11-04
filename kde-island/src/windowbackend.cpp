// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

#include "windowbackend.h"

#include <QGuiApplication>
#include <QScreen>

#ifdef HAVE_LAYERSHELL
#include <LayerShellQt/Shell>
#include <LayerShellQt/Window>
#endif

WindowBackend::WindowBackend(QWindow *window, QObject *parent)
    : QObject(parent), m_window(window) {
    connect(m_window, &QWindow::screenChanged, this, &WindowBackend::measureInset);
    // ISLE_IN_BAR=0 hangs the closed island below the bar instead.
    m_inBar = qEnvironmentVariable("ISLE_IN_BAR", "1") != QLatin1String("0");
}

quintptr WindowBackend::windowId() const {
    return m_window ? m_window->winId() : 0;
}

void WindowBackend::attach() {
    const bool wayland =
        qgetenv("XDG_SESSION_TYPE") == QByteArrayLiteral("wayland") ||
        !qgetenv("WAYLAND_DISPLAY").isEmpty();

#ifdef HAVE_LAYERSHELL
    if (wayland) {
        if (auto *layer = LayerShellQt::Window::get(m_window)) {
            layer->setLayer(LayerShellQt::Window::LayerTop);
            layer->setAnchors(LayerShellQt::Window::AnchorTop);
            // 0: overlay the panel instead of pushing the screen aside.
            layer->setExclusiveZone(0);
            layer->setKeyboardInteractivity(
                LayerShellQt::Window::KeyboardInteractivityNone);
            layer->setScope(QStringLiteral("isle-island"));
            m_layerShell = true;
        }
    }
#endif

    if (!m_layerShell) {
        // X11 (or Wayland without layer-shell): frameless, on top of
        // everything, unmanaged, and never taking focus from the user.
        m_window->setFlags(Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint |
                           Qt::WindowDoesNotAcceptFocus |
                           Qt::X11BypassWindowManagerHint);
    }

    measureInset();
}

void WindowBackend::measureInset() {
    QScreen *screen = m_window ? m_window->screen() : QGuiApplication::primaryScreen();
    if (!screen)
        return;
    // A panel at the top edge shrinks the available geometry; the difference
    // is exactly the panel's height, wherever the user put it.
    const QRect full = screen->geometry();
    const QRect usable = screen->availableGeometry();
    const int inset = qMax(0, usable.top() - full.top());
    if (inset == m_topInset)
        return;
    m_topInset = inset;
    emit insetChanged();
}

void WindowBackend::setInputMask(int x, int y, int width, int height) {
    if (!m_window || width <= 0 || height <= 0)
        return;
    const QRegion region(x, y, width, height);
    if (region == m_mask)
        return;
    m_mask = region;
    // On Wayland Qt maps this to the surface's input region, so the masked
    // parts stay visible but ignore the pointer.
    m_window->setMask(m_mask);
}
