// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

#include "daemonclient.h"
#include "spring.h"
#include "windowbackend.h"

#include <QDBusConnection>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QQmlContext>
#include <QQuickView>
#include <QScreen>

namespace {
// Room for the expanded island plus its shoulders and drop shadow.
constexpr int WINDOW_WIDTH = 660;
constexpr int WINDOW_HEIGHT = 440;
// The name a frontend claims to be allowed to call isled's guarded methods
// (see crates/isle-daemon/src/caller.rs).
constexpr auto ISLAND_NAME = "io.github.zickrian.isle.Island";
} // namespace

int main(int argc, char *argv[]) {
    QGuiApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("isle-island"));
    app.setApplicationDisplayName(QStringLiteral("Isle"));
    app.setOrganizationDomain(QStringLiteral("zickrian.github.io"));

    // Isle's own typeface, shipped with the extension.
    QFontDatabase::addApplicationFont(QStringLiteral(":/fonts/InterVariable.ttf"));

    // Claim the frontend name so isled's clipboard, assistant and agent
    // methods answer us. First claim wins, like GNOME Shell's own name.
    QDBusConnection bus = QDBusConnection::sessionBus();
    const bool claimed = bus.registerService(QString::fromLatin1(ISLAND_NAME));
    if (!claimed) {
        qWarning("isle-island: could not claim %s; guarded isled methods will "
                 "refuse this frontend", ISLAND_NAME);
    }

    qmlRegisterType<Spring>("Isle", 1, 0, "Spring");

    QQuickView view;
    view.setColor(Qt::transparent);
    view.setResizeMode(QQuickView::SizeRootObjectToView);
    view.resize(WINDOW_WIDTH, WINDOW_HEIGHT);
    view.setTitle(QStringLiteral("Isle"));

    WindowBackend backend(&view);
    backend.attach();

    // Without a compositor positioning us, centre on the screen ourselves.
    if (!backend.layerShell()) {
        if (QScreen *screen = view.screen()) {
            const QRect full = screen->geometry();
            view.setPosition(full.x() + (full.width() - WINDOW_WIDTH) / 2, full.y());
        }
    }

    DaemonClient daemon;
    view.rootContext()->setContextProperty(QStringLiteral("daemon"), &daemon);
    // ISLE_THEME=glass gives the see-through look (theme.js); black is Isle's
    // own default.
    view.rootContext()->setContextProperty(
        QStringLiteral("initialTheme"),
        qEnvironmentVariable("ISLE_THEME", "black"));
    view.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);

    view.setSource(QUrl(QStringLiteral("qrc:/Island.qml")));
    if (view.rootObject() == nullptr)
        return 1;

    view.show();
    return app.exec();
}
