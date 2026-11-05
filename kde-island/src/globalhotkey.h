// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

#pragma once

#include <QObject>

// The island's global shortcut. On KDE a global key is registered through
// KGlobalAccel, so it shows up in System Settings → Shortcuts and the user can
// rebind it there; without the dev package the class does nothing.
class GlobalHotkey : public QObject {
    Q_OBJECT

public:
    explicit GlobalHotkey(QObject *parent = nullptr);

    // Registers Super+V. Call once, after the QML is loaded.
    void registerShortcut();

    bool available() const { return m_available; }

signals:
    // The user pressed the shortcut: open the island on the clipboard.
    void clipsRequested();

private:
    bool m_available = false;
};
