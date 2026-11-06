// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

#include "windowbackend.h"

#include <QCursor>
#include <QDebug>
#include <QGuiApplication>
#include <QScreen>
#include <X11/Xlib.h>

#ifdef HAVE_LAYERSHELL
#include <LayerShellQt/Shell>
#include <LayerShellQt/Window>
#endif

WindowBackend::WindowBackend(QWindow *window, QObject *parent)
    : QObject(parent), m_window(window) {
    connect(m_window, &QWindow::screenChanged, this, &WindowBackend::applyScreen);
    connect(qApp, &QGuiApplication::screenAdded, this, &WindowBackend::applyScreen);
    connect(qApp, &QGuiApplication::screenRemoved, this, &WindowBackend::applyScreen);
    // Wayland does not let a client read the global pointer.
    const bool wayland =
        qgetenv("XDG_SESSION_TYPE") == QByteArrayLiteral("wayland") ||
        !qgetenv("WAYLAND_DISPLAY").isEmpty();
    m_pointerQueryable = !wayland;
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
        // Qt::WindowDoesNotAcceptFocus removed so text inputs (reminders,
        // search, assistant chat) can receive keystrokes.
        // Keep X11BypassWindowManagerHint so the window sits at y=0 over the top bar
        // without KWin reparenting it under panels.
        m_window->setFlags(Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint |
                           Qt::X11BypassWindowManagerHint);
    }

    applyScreen();
}

void WindowBackend::applyScreen() {
    if (!m_window)
        return;
    const auto screens = QGuiApplication::screens();
    if (screens.isEmpty())
        return;
    // A screen we picked earlier may be gone (HDMI unplugged): fall back to
    // the primary instead of silently landing on whatever is left.
    if (m_targetScreenIndex < 0 || m_targetScreenIndex >= screens.size()) {
        for (int i = 0; i < screens.size(); ++i) {
            if (screens.at(i) == QGuiApplication::primaryScreen()) {
                m_targetScreenIndex = i; break;
            }
        }
        if (m_targetScreenIndex < 0 || m_targetScreenIndex >= screens.size())
            m_targetScreenIndex = 0;
    }
    int idx = qBound(0, m_targetScreenIndex, screens.size() - 1);
    m_targetScreenIndex = idx;
    QScreen *screen = screens.at(idx);

    // Layer-shell: tell it which output to live on.
#ifdef HAVE_LAYERSHELL
    if (m_layerShell) {
        if (auto *layer = LayerShellQt::Window::get(m_window))
            layer->setDesiredOutput(screen);
    } else {
        m_window->setScreen(screen);
    }
#else
    m_window->setScreen(screen);
#endif

    // Position at the top centre of the chosen screen (X11 fallback).
    if (!m_layerShell) {
        const QRect full = screen->geometry();
        m_window->setPosition(full.x() + (full.width() - m_window->width()) / 2, full.y());
    }

    measureInset();
    emit targetScreenChanged();
    emit screensChanged();
}

void WindowBackend::measureInset() {
    const auto screens = QGuiApplication::screens();
    QScreen *screen = (m_targetScreenIndex >= 0 && m_targetScreenIndex < screens.size())
                          ? screens.at(m_targetScreenIndex)
                          : QGuiApplication::primaryScreen();
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

bool WindowBackend::pointerInside(int x, int y, int width, int height) const {
    if (!m_window || !m_pointerQueryable)
        return false;
    return QRect(x, y, width, height).contains(QCursor::pos() - m_window->position());
}

void WindowBackend::requestFrame() {
    if (m_window)
        m_window->requestUpdate();
}

void WindowBackend::grabKeyboardFocus() {
    if (!m_window)
        return;
    m_window->requestActivate();
    if (m_pointerQueryable) {
        // On X11, an override-redirect window is bypassed by the window manager,
        // so XSetInputFocus must be called directly to direct keystrokes to it.
        Display *dpy = XOpenDisplay(nullptr);
        if (dpy) {
            XSetInputFocus(dpy, (::Window)m_window->winId(), RevertToParent, CurrentTime);
            XFlush(dpy);
            XCloseDisplay(dpy);
        }
    }
}

void WindowBackend::setTargetScreenIndex(int index) {
    if (index == m_targetScreenIndex)
        return;
    m_targetScreenIndex = index;
    applyScreen();
}

QStringList WindowBackend::screenNames() const {
    QStringList names;
    for (QScreen *s : QGuiApplication::screens()) {
        QString label = QStringLiteral("%1 (%2x%3)").arg(s->name()).arg(s->geometry().width()).arg(s->geometry().height());
        if (s == QGuiApplication::primaryScreen())
            label += QStringLiteral("  (primary)");
        names.append(label);
    }
    return names;
}

void WindowBackend::setInputMask(int x, int y, int width, int height) {
    if (!m_window || width <= 0 || height <= 0)
        return;
    const QRegion region(x, y, width, height);
    if (region == m_mask)
        return;
    if (qEnvironmentVariableIsSet("ISLE_TRACE"))
        qInfo("setInputMask %d,%d %dx%d", x, y, width, height);
    m_mask = region;
    // On Wayland Qt maps this to the surface's input region, so the masked
    // parts stay visible but ignore the pointer.
    m_window->setMask(m_mask);
}
