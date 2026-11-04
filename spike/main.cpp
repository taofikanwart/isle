// SPDX-License-Identifier: GPL-3.0-or-later
// Feasibility spike for the KDE port of Isle. Throwaway code.
//
// Proves five things before the real port starts:
//   1. a layer-shell window stacks above the Plasma panel at the top centre
//   2. clicks outside the notch pass through (input mask follows the notch)
//   3. hover open/close driven by retargetable damped springs feels right
//   4. a translucent "glass" look renders without KWin blur
//   5. QML can read isled's Media1 state and call PlayPause over D-Bus

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QGuiApplication>
#include <QQmlContext>
#include <QQuickItem>
#include <QQuickView>
#include <QRegion>
#include <QTimer>
#include <cmath>

#ifdef HAVE_LAYERSHELL
#include <LayerShellQt/shell.h>
#include <LayerShellQt/window.h>
#endif

// ---------------------------------------------------------------------------
// Spring: port of gnome-extension/src/spring.js. One animated value pulled
// toward its target by a damped spring; retargetable mid-flight, keeping
// velocity, so the island never jolts.
class Spring : public QObject {
    Q_OBJECT
    Q_PROPERTY(qreal value READ value NOTIFY valueChanged)
    Q_PROPERTY(qreal target READ target WRITE setTarget NOTIFY targetChanged)
    Q_PROPERTY(qreal stiffness MEMBER m_stiffness)
    Q_PROPERTY(qreal damping MEMBER m_damping)

    static constexpr qreal MAX_STEP = 1.0 / 240.0;
    static constexpr qreal MAX_FRAME = 0.25;
    static constexpr qreal REST_DISTANCE = 0.25;
    static constexpr qreal REST_SPEED = 2.0;

public:
    explicit Spring(QObject *parent = nullptr)
        : QObject(parent) {
        m_timer.setInterval(8); // ~120 Hz; the integrator substeps anyway
        connect(&m_timer, &QTimer::timeout, this, &Spring::tick);
    }

    qreal value() const { return m_value; }
    qreal target() const { return m_target; }

    void setTarget(qreal target) {
        if (qFuzzyCompare(m_target, target))
            return;
        m_target = target;
        emit targetChanged();
        if (!settled()) {
            m_clock.start();
            m_timer.start();
        }
    }

    Q_INVOKABLE void reset(qreal value) {
        m_value = m_target = value;
        m_velocity = 0;
        m_timer.stop();
        emit valueChanged();
    }

signals:
    void valueChanged();
    void targetChanged();

private:
    bool settled() const {
        return std::abs(m_value - m_target) < REST_DISTANCE &&
            std::abs(m_velocity) < REST_SPEED;
    }

    void tick() {
        qreal dt = m_clock.isValid() ? m_clock.restart() / 1000.0 : 0.016;
        qreal remaining = std::clamp(dt, 0.0, MAX_FRAME);
        while (remaining > 0 && !settled()) {
            const qreal h = std::min(remaining, MAX_STEP);
            const qreal acceleration =
                -m_stiffness * (m_value - m_target) - m_damping * m_velocity;
            m_velocity += acceleration * h;
            m_value += m_velocity * h;
            remaining -= h;
        }
        if (settled()) {
            m_value = m_target;
            m_velocity = 0;
            m_timer.stop();
        }
        emit valueChanged();
    }

    // ISLAND config from spring.js: ~3.5% overshoot, at rest by ~0.57 s.
    qreal m_stiffness = 155;
    qreal m_damping = 18;
    qreal m_value = 0;
    qreal m_target = 0;
    qreal m_velocity = 0;
    QTimer m_timer;
    QElapsedTimer m_clock;
};

// ---------------------------------------------------------------------------
// DaemonClient: the thinnest possible isled client. Reads Media1.NowPlaying
// and calls PlayPause, which is all pass criterion 5 needs.
class DaemonClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString nowPlaying READ nowPlaying NOTIFY nowPlayingChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY nowPlayingChanged)

    static constexpr auto SERVICE = "io.github.zickrian.isle.Daemon";
    static constexpr auto PATH = "/io/github/zickrian/isle/Daemon";
    static constexpr auto MEDIA = "io.github.zickrian.isle.Media1";

public:
    explicit DaemonClient(QObject *parent = nullptr)
        : QObject(parent) {
        QDBusConnection::sessionBus().connect(
            SERVICE, PATH, "org.freedesktop.DBus.Properties",
            "PropertiesChanged", this,
            SLOT(onPropertiesChanged(QString, QVariantMap, QStringList)));
        refresh();
    }

    QString nowPlaying() const { return m_nowPlaying; }
    bool connected() const { return m_connected; }

    Q_INVOKABLE void playPause() {
        QDBusInterface media(SERVICE, PATH, MEDIA);
        media.asyncCall(QStringLiteral("PlayPause"));
    }

private slots:
    void onPropertiesChanged(const QString &interface,
                             const QVariantMap &changed, const QStringList &) {
        if (interface != QLatin1String(MEDIA))
            return;
        const auto it = changed.find(QStringLiteral("NowPlaying"));
        if (it != changed.end())
            setNowPlaying(it->toString(), true);
    }

private:
    void refresh() {
        QDBusInterface props(SERVICE, PATH,
                             QStringLiteral("org.freedesktop.DBus.Properties"));
        QDBusReply<QVariant> reply = props.call(
            QStringLiteral("Get"), QString::fromLatin1(MEDIA),
            QStringLiteral("NowPlaying"));
        if (reply.isValid())
            setNowPlaying(reply.value().toString(), true);
        else
            setNowPlaying(QStringLiteral("isled unreachable: %1")
                              .arg(reply.error().message()),
                          false);
    }

    void setNowPlaying(const QString &value, bool connected) {
        if (m_nowPlaying == value && m_connected == connected)
            return;
        m_nowPlaying = value;
        m_connected = connected;
        emit nowPlayingChanged();
    }

    QString m_nowPlaying;
    bool m_connected = false;

signals:
    void nowPlayingChanged();
};

// ---------------------------------------------------------------------------

int main(int argc, char *argv[]) {
    QGuiApplication::setAttribute(Qt::AA_EnableHighDpiScaling);

    const bool wayland =
        qgetenv("XDG_SESSION_TYPE") == QByteArrayLiteral("wayland") ||
        !qgetenv("WAYLAND_DISPLAY").isEmpty();

#ifdef HAVE_LAYERSHELL
    // Must happen before the first window is created.
    if (wayland)
        LayerShellQt::Shell::useLayerShell();
#endif

    QGuiApplication app(argc, argv);

    qmlRegisterType<Spring>("Isle.Spike", 1, 0, "Spring");

    QQuickView view;
    view.setColor(Qt::transparent);
    view.setResizeMode(QQuickView::SizeRootObjectToView);

    DaemonClient daemon;
    view.rootContext()->setContextProperty(QStringLiteral("daemon"), &daemon);

    bool layerShellActive = false;
#ifdef HAVE_LAYERSHELL
    if (wayland) {
        if (auto *layer = LayerShellQt::Window::get(&view)) {
            layer->setLayer(LayerShellQt::Window::LayerTop);
            layer->setAnchors(LayerShellQt::Window::AnchorTop);
            layer->setExclusiveZone(0); // overlay; push nothing aside
            layer->setKeyboardInteractivity(
                LayerShellQt::Window::KeyboardInteractivityNone);
            layer->setScope(QStringLiteral("isle-spike"));
            layerShellActive = true;
        }
    }
#endif
    if (!layerShellActive) {
        // X11 fallback: frameless, always on top, unmanaged, no focus steal.
        view.setFlags(Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint |
                      Qt::WindowDoesNotAcceptFocus |
                      Qt::X11BypassWindowManagerHint);
    }

    view.rootContext()->setContextProperty(QStringLiteral("layerShellActive"),
                                           layerShellActive);
    view.setSource(QUrl(QStringLiteral("qrc:/Spike.qml")));
    if (!view.rootObject())
        return 1;

    // The window always has the expanded size; the input mask shrinks to the
    // notch so everything outside it clicks through (criterion 2).
    const int W = 520, H = 280;
    view.resize(W, H);
    if (!layerShellActive) {
        const QRect screen = view.screen()->geometry();
        view.setPosition(screen.x() + (screen.width() - W) / 2, screen.y());
    }

    QObject *root = view.rootObject();
    auto updateMask = [&view, root]() {
        const QRectF r(root->property("maskX").toReal(),
                       root->property("maskY").toReal(),
                       root->property("maskWidth").toReal(),
                       root->property("maskHeight").toReal());
        view.setMask(QRegion(r.toAlignedRect()));
    };
    QObject::connect(root, SIGNAL(maskChanged()), &view,
                     SLOT(update()));            // repaint on change
    QTimer maskTimer;                            // mask follows the spring
    maskTimer.setInterval(16);
    QObject::connect(&maskTimer, &QTimer::timeout, &view, updateMask);
    maskTimer.start();
    updateMask();

    view.show();
    return app.exec();
}

#include "main.moc"
