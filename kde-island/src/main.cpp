// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

#include "daemonclient.h"
#include "spring.h"
#include "windowbackend.h"

#include <QDateTime>
#include <QDBusConnection>
#include <QDebug>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QQmlContext>
#include <QQuickView>
#include <QScreen>

// Carries the render loop's delta to QML: signals beat QMetaObject calls and
// keep the springs out of QML's own timer machinery.
class FrameClock : public QObject {
    Q_OBJECT

public:
    void tick(qreal dt) { emit ticked(dt); }

signals:
    void ticked(qreal dt);
};

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

    // Must exist before the QML is created: a context property added later is
    // invisible to items already instantiated.
    FrameClock frames;
    view.rootContext()->setContextProperty(QStringLiteral("frames"), &frames);

    view.setSource(QUrl(QStringLiteral("qrc:/Island.qml")));
    if (view.rootObject() == nullptr)
        return 1;

    // One spring step per painted frame, with the frame's own delta: the
    // frame clock Isle uses through Clutter, on Qt's render loop.
    qint64 lastFrame = 0;
    QObject::connect(&view, &QQuickWindow::frameSwapped, [&frames, lastFrame]() mutable {
        const qint64 now = QDateTime::currentMSecsSinceEpoch();
        const qreal dt = lastFrame == 0 ? 1.0 / 60.0 : (now - lastFrame) / 1000.0;
        lastFrame = now;
        if (qEnvironmentVariableIsSet("ISLE_TRACE"))
            qInfo("F %lld", now);
        frames.tick(dt);
    });

    view.show();
    return app.exec();
}

#include "main.moc"
