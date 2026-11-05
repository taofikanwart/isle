// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

#include "globalhotkey.h"

#ifdef HAVE_KGLOBALACCEL
#include <KGlobalAccel>
#include <QAction>
#include <QKeySequence>
#endif

GlobalHotkey::GlobalHotkey(QObject *parent)
    : QObject(parent) {}

void GlobalHotkey::registerShortcut() {
#ifdef HAVE_KGLOBALACCEL
    auto *action = new QAction(this);
    action->setObjectName(QStringLiteral("show_clipboard"));
    action->setText(QStringLiteral("Show the clipboard"));
    // Shown in System Settings; the component is the app id, so the entry is
    // found under Isle rather than a nameless one.
    action->setProperty("componentName", QStringLiteral("isle-island"));
    action->setProperty("componentDisplayName", QStringLiteral("Isle"));

    connect(action, &QAction::triggered, this, &GlobalHotkey::clipsRequested);

    const QKeySequence key(QStringLiteral("Meta+V"));
    // Asked for every start, so a rebind the user made survives: only a key
    // nobody set is filled with our default.
    if (KGlobalAccel::self()->shortcut(action).isEmpty())
        KGlobalAccel::self()->setShortcut(action, {key},
                                          KGlobalAccel::NoAutoloading);
    KGlobalAccel::self()->setDefaultShortcut(action, {key});
    m_available = true;
#else
    // Built without the KGlobalAccel dev package: the shortcut is unavailable
    // and the island still works through its tabs.
#endif
}
