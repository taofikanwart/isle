// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

#include "daemonclient.h"

#pragma push_macro("signals")
#undef signals
#include <gio/gio.h>
#pragma pop_macro("signals")

#include <QClipboard>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDateTime>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

namespace {
constexpr auto SERVICE = "io.github.zickrian.isle.Daemon";
constexpr auto PATH = "/io/github/zickrian/isle/Daemon";
constexpr auto MEDIA = "io.github.zickrian.isle.Media1";
constexpr auto POMODORO = "io.github.zickrian.isle.Pomodoro1";
constexpr auto TODO = "io.github.zickrian.isle.Todo1";
constexpr auto CLIPBOARD = "io.github.zickrian.isle.Clipboard1";
constexpr auto CALENDAR = "io.github.zickrian.isle.Calendar1";

// GIO filter for notifications
GDBusMessage *notificationFilter(GDBusConnection *connection,
                                 GDBusMessage *message,
                                 gboolean incoming,
                                 gpointer user_data) {
    Q_UNUSED(connection)
    Q_UNUSED(incoming)
    if (g_dbus_message_get_message_type(message) == G_DBUS_MESSAGE_TYPE_METHOD_CALL &&
        g_strcmp0(g_dbus_message_get_member(message), "Notify") == 0) {
        GVariant *body = g_dbus_message_get_body(message);
        if (body && g_variant_n_children(body) >= 5) {
            const char *app = g_variant_get_string(g_variant_get_child_value(body, 0), nullptr);
            const char *summary = g_variant_get_string(g_variant_get_child_value(body, 3), nullptr);
            const char *text = g_variant_get_string(g_variant_get_child_value(body, 4), nullptr);

            auto *client = static_cast<DaemonClient *>(user_data);
            QMetaObject::invokeMethod(client, [client,
                                               appStr = QString::fromUtf8(app ? app : ""),
                                               sumStr = QString::fromUtf8(summary ? summary : ""),
                                               txtStr = QString::fromUtf8(text ? text : "")] {
                client->appendNotification(appStr, sumStr, txtStr);
            }, Qt::QueuedConnection);
        }
    }
    return message;
}
} // namespace

DaemonClient::DaemonClient(QObject *parent)
    : QObject(parent) {
    loadSettings();

    // D-Bus property changes
    QDBusConnection::sessionBus().connect(
        QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
        QStringLiteral("org.freedesktop.DBus.Properties"),
        QStringLiteral("PropertiesChanged"), this,
        SLOT(onPropertiesChanged(QString, QVariantMap, QStringList)));

    // System clipboard monitoring
    if (QClipboard *clipboard = QGuiApplication::clipboard()) {
        connect(clipboard, &QClipboard::dataChanged, this, &DaemonClient::onClipboardChanged);
    }

    setupNotificationListener();
    refresh();
}

void DaemonClient::loadSettings() {
    QSettings s(QStringLiteral("isle"), QStringLiteral("island"));
    m_themeName = s.value(QStringLiteral("themeName"), QStringLiteral("black")).toString();
    m_glassTint = s.value(QStringLiteral("glassTint"), 0).toInt();
    m_inBar = s.value(QStringLiteral("inBar"), true).toBool();
    m_notchDepth = s.value(QStringLiteral("notchDepth"), 30).toInt();
}

void DaemonClient::saveSettings() {
    QSettings s(QStringLiteral("isle"), QStringLiteral("island"));
    s.setValue(QStringLiteral("themeName"), m_themeName);
    s.setValue(QStringLiteral("glassTint"), m_glassTint);
    s.setValue(QStringLiteral("inBar"), m_inBar);
    s.setValue(QStringLiteral("notchDepth"), m_notchDepth);
}

void DaemonClient::setThemeName(const QString &val) {
    if (m_themeName == val)
        return;
    m_themeName = val;
    saveSettings();
    emit settingsChanged();
}

void DaemonClient::setGlassTint(int val) {
    val = qBound(0, val, 100);
    if (m_glassTint == val)
        return;
    m_glassTint = val;
    saveSettings();
    emit settingsChanged();
}

void DaemonClient::setInBar(bool val) {
    if (m_inBar == val)
        return;
    m_inBar = val;
    saveSettings();
    emit settingsChanged();
}

void DaemonClient::setNotchDepth(int val) {
    val = qBound(20, val, 50);
    if (m_notchDepth == val)
        return;
    m_notchDepth = val;
    saveSettings();
    emit settingsChanged();
}

void DaemonClient::setupNotificationListener() {
    GError *error = nullptr;
    GDBusConnection *bus = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
    if (!bus) {
        if (error) g_error_free(error);
        return;
    }
    const char *rule = "type='method_call',interface='org.freedesktop.Notifications',member='Notify',eavesdrop='true'";
    g_dbus_connection_call(bus, "org.freedesktop.DBus", "/org/freedesktop/DBus",
                           "org.freedesktop.DBus", "AddMatch",
                           g_variant_new("(s)", rule), nullptr,
                           G_DBUS_CALL_FLAGS_NONE, 2000, nullptr, nullptr, nullptr);
    g_dbus_connection_add_filter(bus, notificationFilter, this, nullptr);
}

// Media
void DaemonClient::playPause() {
    QDBusInterface media(QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
                         QString::fromLatin1(MEDIA));
    media.asyncCall(QStringLiteral("PlayPause"));
}

void DaemonClient::next() {
    QDBusInterface media(QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
                         QString::fromLatin1(MEDIA));
    media.asyncCall(QStringLiteral("Next"));
}

void DaemonClient::previous() {
    QDBusInterface media(QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
                         QString::fromLatin1(MEDIA));
    media.asyncCall(QStringLiteral("Previous"));
}

// Pomodoro
void DaemonClient::setLyricsEnabled(bool enabled) {
    QDBusInterface media(QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
                         QString::fromLatin1(MEDIA));
    media.asyncCall(QStringLiteral("SetLyrics"), enabled);
}

void DaemonClient::seekTo(qint64 positionUs) {
    QDBusInterface media(QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
                         QString::fromLatin1(MEDIA));
    media.asyncCall(QStringLiteral("SetPosition"), positionUs);
}

void DaemonClient::pomodoroToggle() {
    QDBusInterface pomo(QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
                        QString::fromLatin1(POMODORO));
    pomo.asyncCall(m_pomodoroRunning ? QStringLiteral("Pause")
                                     : QStringLiteral("Start"));
}

void DaemonClient::pomodoroStop() {
    QDBusInterface pomo(QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
                        QString::fromLatin1(POMODORO));
    pomo.asyncCall(QStringLiteral("Stop"));
}

void DaemonClient::pomodoroSkip() {
    QDBusInterface pomo(QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
                        QString::fromLatin1(POMODORO));
    pomo.asyncCall(QStringLiteral("Skip"));
}

double DaemonClient::pomodoroRemaining() const {
    if (m_pomodoroRunning && m_pomodoroEndsAtMs > 0) {
        const qint64 left = m_pomodoroEndsAtMs - QDateTime::currentMSecsSinceEpoch();
        return qMax(0.0, left / 1000.0);
    }
    return m_pomodoroRemaining;
}

// Todo
void DaemonClient::todoAdd(const QString &text) {
    if (text.trimmed().isEmpty())
        return;
    QDBusInterface todo(QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
                        QString::fromLatin1(TODO));
    todo.asyncCall(QStringLiteral("Add"), text.trimmed());
}

void DaemonClient::todoSetDone(quint64 id, bool done) {
    QDBusInterface todo(QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
                        QString::fromLatin1(TODO));
    todo.asyncCall(QStringLiteral("SetDone"), id, done);
}

void DaemonClient::todoRename(quint64 id, const QString &text) {
    if (text.trimmed().isEmpty())
        return;
    QDBusInterface todo(QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
                        QString::fromLatin1(TODO));
    todo.asyncCall(QStringLiteral("Rename"), id, text.trimmed());
}

void DaemonClient::todoRemove(quint64 id) {
    QDBusInterface todo(QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
                        QString::fromLatin1(TODO));
    todo.asyncCall(QStringLiteral("Remove"), id);
}

// Clipboard
void DaemonClient::onClipboardChanged() {
    if (QClipboard *clipboard = QGuiApplication::clipboard()) {
        const QString text = clipboard->text();
        if (!text.isEmpty() && text != m_lastCopiedText) {
            m_lastCopiedText = text;
            QDBusInterface clip(QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
                                QString::fromLatin1(CLIPBOARD));
            clip.asyncCall(QStringLiteral("AddText"), text, QStringLiteral(""));
        }
    }
}

void DaemonClient::clipCopy(const QString &text) {
    if (QClipboard *clipboard = QGuiApplication::clipboard()) {
        m_lastCopiedText = text;
        clipboard->setText(text);
    }
}

void DaemonClient::clipSetPinned(quint64 id, bool pinned) {
    QDBusInterface clip(QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
                        QString::fromLatin1(CLIPBOARD));
    clip.asyncCall(QStringLiteral("SetPinned"), id, pinned);
}

void DaemonClient::clipRemove(quint64 id) {
    QDBusInterface clip(QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
                        QString::fromLatin1(CLIPBOARD));
    clip.asyncCall(QStringLiteral("Remove"), id);
}

void DaemonClient::clipClear() {
    QDBusInterface clip(QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
                        QString::fromLatin1(CLIPBOARD));
    clip.asyncCall(QStringLiteral("Clear"));
}

// Calendar
void DaemonClient::calendarAdd(const QString &date, const QString &title) {
    if (date.trimmed().isEmpty() || title.trimmed().isEmpty())
        return;
    QDBusInterface cal(QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
                       QString::fromLatin1(CALENDAR));
    cal.asyncCall(QStringLiteral("Add"), date.trimmed(), title.trimmed());
}

void DaemonClient::calendarRemove(quint64 id) {
    QDBusInterface cal(QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
                       QString::fromLatin1(CALENDAR));
    cal.asyncCall(QStringLiteral("Remove"), id);
}

void DaemonClient::appendNotification(const QString &app, const QString &summary, const QString &text) {
    QVariantMap item;
    item[QStringLiteral("id")] = QDateTime::currentMSecsSinceEpoch();
    item[QStringLiteral("app")] = app.isEmpty() ? QStringLiteral("System") : app;
    item[QStringLiteral("summary")] = summary;
    item[QStringLiteral("body")] = text;
    item[QStringLiteral("time")] = QDateTime::currentDateTime().toString(QStringLiteral("hh:mm"));

    m_notifications.prepend(item);
    if (m_notifications.size() > 30)
        m_notifications.removeLast();

    emit notificationsChanged();
    emit notificationArrived(summary, text, app);
}

// Notifications
void DaemonClient::notificationDismiss(int index) {
    if (index >= 0 && index < m_notifications.size()) {
        m_notifications.removeAt(index);
        emit notificationsChanged();
    }
}

void DaemonClient::notificationClearAll() {
    if (!m_notifications.isEmpty()) {
        m_notifications.clear();
        emit notificationsChanged();
    }
}

void DaemonClient::onPropertiesChanged(const QString &interface,
                                       const QVariantMap &changed,
                                       const QStringList &invalidated) {
    Q_UNUSED(invalidated)
    if (interface == QLatin1String(MEDIA)) {
        const auto nowPlaying = changed.constFind(QStringLiteral("NowPlaying"));
        if (nowPlaying != changed.constEnd())
            parse(nowPlaying->toString());
        const auto lyrics = changed.constFind(QStringLiteral("Lyrics"));
        if (lyrics != changed.constEnd())
            parseLyrics(lyrics->toString());
    } else if (interface == QLatin1String(POMODORO)) {
        const auto it = changed.constFind(QStringLiteral("State"));
        if (it != changed.constEnd())
            parsePomodoro(it->toString());
    } else if (interface == QLatin1String(TODO)) {
        const auto it = changed.constFind(QStringLiteral("Items"));
        if (it != changed.constEnd())
            parseTasks(it->toString());
    } else if (interface == QLatin1String(CLIPBOARD)) {
        const auto it = changed.constFind(QStringLiteral("Items"));
        if (it != changed.constEnd())
            parseClips(it->toString());
    } else if (interface == QLatin1String(CALENDAR)) {
        const auto it = changed.constFind(QStringLiteral("Events"));
        if (it != changed.constEnd())
            parseEvents(it->toString());
    }
}

void DaemonClient::refresh() {
    QDBusInterface props(QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
                         QStringLiteral("org.freedesktop.DBus.Properties"));

    // Media
    QDBusReply<QVariant> reply = props.call(
        QStringLiteral("Get"), QString::fromLatin1(MEDIA), QStringLiteral("NowPlaying"));
    if (reply.isValid()) {
        m_connected = true;
        parse(reply.value().toString());
    } else {
        m_connected = false;
        emit changed();
    }

    // Lyrics
    reply = props.call(
        QStringLiteral("Get"), QString::fromLatin1(MEDIA), QStringLiteral("Lyrics"));
    if (reply.isValid())
        parseLyrics(reply.value().toString());

    // Pomodoro
    reply = props.call(
        QStringLiteral("Get"), QString::fromLatin1(POMODORO), QStringLiteral("State"));
    if (reply.isValid())
        parsePomodoro(reply.value().toString());

    // Tasks
    reply = props.call(
        QStringLiteral("Get"), QString::fromLatin1(TODO), QStringLiteral("Items"));
    if (reply.isValid())
        parseTasks(reply.value().toString());

    // Clips
    reply = props.call(
        QStringLiteral("Get"), QString::fromLatin1(CLIPBOARD), QStringLiteral("Items"));
    if (reply.isValid())
        parseClips(reply.value().toString());

    // Calendar
    reply = props.call(
        QStringLiteral("Get"), QString::fromLatin1(CALENDAR), QStringLiteral("Events"));
    if (reply.isValid())
        parseEvents(reply.value().toString());
}

void DaemonClient::parse(const QString &json) {
    const QJsonObject object = QJsonDocument::fromJson(json.toUtf8()).object();

    const bool available = object.value(QStringLiteral("available")).toBool();
    const QString title = object.value(QStringLiteral("title")).toString();
    const QString artist = object.value(QStringLiteral("artist")).toString();
    const QString album = object.value(QStringLiteral("album")).toString();
    const QString artPath = object.value(QStringLiteral("art_path")).toString();
    const bool playing =
        object.value(QStringLiteral("status")).toString() == QLatin1String("Playing");
    const bool canPlayPause = object.value(QStringLiteral("can_play_pause")).toBool();
    const bool canGoNext = object.value(QStringLiteral("can_go_next")).toBool();
    const bool canGoPrevious = object.value(QStringLiteral("can_go_previous")).toBool();
    const double position = object.value(QStringLiteral("position_us")).toDouble() / 1e6;
    const double duration = object.value(QStringLiteral("length_us")).toDouble() / 1e6;

    if (m_available == available && m_title == title && m_artist == artist &&
        m_album == album && m_artPath == artPath && m_playing == playing &&
        m_canPlayPause == canPlayPause && m_canGoNext == canGoNext &&
        m_canGoPrevious == canGoPrevious && qFuzzyCompare(m_position + 1, position + 1) &&
        qFuzzyCompare(m_duration + 1, duration + 1) && m_connected)
        return;

    m_available = available;
    m_title = title;
    m_artist = artist;
    m_album = album;
    m_artPath = artPath;
    m_playing = playing;
    m_canPlayPause = canPlayPause;
    m_canGoNext = canGoNext;
    m_canGoPrevious = canGoPrevious;
    m_position = position;
    m_duration = duration;
    m_connected = true;
    emit changed();
}

void DaemonClient::parsePomodoro(const QString &json) {
    const QJsonObject o = QJsonDocument::fromJson(json.toUtf8()).object();
    m_pomodoroPhase = o.value(QStringLiteral("phase")).toString(QStringLiteral("idle"));
    m_pomodoroRunning = o.value(QStringLiteral("running")).toBool();
    m_pomodoroRemaining = o.value(QStringLiteral("remaining_ms")).toDouble() / 1000.0;
    m_pomodoroDuration = o.value(QStringLiteral("duration_ms")).toDouble() / 1000.0;
    m_pomodoroEndsAtMs = o.value(QStringLiteral("ends_at_ms")).toVariant().toLongLong();
    m_pomodoroSessions = o.value(QStringLiteral("completed_sessions")).toInt();
    emit pomodoroChanged();
}

void DaemonClient::parseTasks(const QString &json) {
    const QJsonArray arr = QJsonDocument::fromJson(json.toUtf8()).array();
    QVariantList list;
    for (const auto &v : arr) {
        const QJsonObject o = v.toObject();
        QVariantMap m;
        m[QStringLiteral("id")] = o.value(QStringLiteral("id")).toVariant().toULongLong();
        m[QStringLiteral("title")] = o.value(QStringLiteral("title")).toString();
        m[QStringLiteral("done")] = o.value(QStringLiteral("done")).toBool();
        list.append(m);
    }
    m_tasks = list;
    emit tasksChanged();
}

void DaemonClient::parseClips(const QString &json) {
    const QJsonArray arr = QJsonDocument::fromJson(json.toUtf8()).array();
    QVariantList list;
    for (const auto &v : arr) {
        const QJsonObject o = v.toObject();
        QVariantMap m;
        m[QStringLiteral("id")] = o.value(QStringLiteral("id")).toVariant().toULongLong();
        m[QStringLiteral("kind")] = o.value(QStringLiteral("kind")).toString();
        m[QStringLiteral("preview")] = o.value(QStringLiteral("preview")).toString();
        m[QStringLiteral("appId")] = o.value(QStringLiteral("app_id")).toString();
        m[QStringLiteral("pinned")] = o.value(QStringLiteral("pinned")).toBool();
        list.append(m);
    }
    m_clips = list;
    emit clipsChanged();
}

void DaemonClient::parseEvents(const QString &json) {
    const QJsonArray arr = QJsonDocument::fromJson(json.toUtf8()).array();
    QVariantList list;
    for (const auto &v : arr) {
        const QJsonObject o = v.toObject();
        QVariantMap m;
        m[QStringLiteral("id")] = o.value(QStringLiteral("id")).toVariant().toULongLong();
        m[QStringLiteral("title")] = o.value(QStringLiteral("title")).toString();
        m[QStringLiteral("date")] = o.value(QStringLiteral("date")).toString();
        m[QStringLiteral("start")] = o.value(QStringLiteral("start")).toString();
        m[QStringLiteral("end")] = o.value(QStringLiteral("end")).toString();
        list.append(m);
    }
    m_events = list;
    emit eventsChanged();
}

void DaemonClient::parseLyrics(const QString &json) {
    const QJsonObject o = QJsonDocument::fromJson(json.toUtf8()).object();
    const QString status = o.value(QStringLiteral("status")).toString(QStringLiteral("none"));
    QVariantList lines;
    for (const auto &v : o.value(QStringLiteral("lines")).toArray()) {
        const QJsonObject line = v.toObject();
        QVariantMap m;
        m[QStringLiteral("time")] = line.value(QStringLiteral("time_ms")).toVariant().toLongLong();
        m[QStringLiteral("text")] = line.value(QStringLiteral("text")).toString();
        lines.append(m);
    }
    if (m_lyricsStatus == status && m_lyricsLines == lines)
        return;
    m_lyricsStatus = status;
    m_lyricsLines = lines;
    emit lyricsChanged();
}
