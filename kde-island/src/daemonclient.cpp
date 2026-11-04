// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

#include "daemonclient.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

namespace {
constexpr auto SERVICE = "io.github.zickrian.isle.Daemon";
constexpr auto PATH = "/io/github/zickrian/isle/Daemon";
constexpr auto MEDIA = "io.github.zickrian.isle.Media1";
constexpr auto POMODORO = "io.github.zickrian.isle.Pomodoro1";
constexpr auto TODO = "io.github.zickrian.isle.Todo1";
} // namespace

DaemonClient::DaemonClient(QObject *parent)
    : QObject(parent) {
    QDBusConnection::sessionBus().connect(
        QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
        QStringLiteral("org.freedesktop.DBus.Properties"),
        QStringLiteral("PropertiesChanged"), this,
        SLOT(onPropertiesChanged(QString, QVariantMap, QStringList)));
    refresh();
}

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

void DaemonClient::onPropertiesChanged(const QString &interface,
                                       const QVariantMap &changed,
                                       const QStringList &invalidated) {
    Q_UNUSED(invalidated)
    if (interface == QLatin1String(MEDIA)) {
        const auto it = changed.constFind(QStringLiteral("NowPlaying"));
        if (it != changed.constEnd())
            parse(it->toString());
    } else if (interface == QLatin1String(POMODORO)) {
        const auto it = changed.constFind(QStringLiteral("State"));
        if (it != changed.constEnd())
            parsePomodoro(it->toString());
    } else if (interface == QLatin1String(TODO)) {
        const auto it = changed.constFind(QStringLiteral("Items"));
        if (it != changed.constEnd())
            parseTasks(it->toString());
    }
}

void DaemonClient::refresh() {
    QDBusInterface props(QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
                         QStringLiteral("org.freedesktop.DBus.Properties"));
    // Media
    QDBusReply<QVariant> reply = props.call(
        QStringLiteral("Get"), QString::fromLatin1(MEDIA),
        QStringLiteral("NowPlaying"));
    if (reply.isValid()) {
        m_connected = true;
        parse(reply.value().toString());
    } else {
        m_connected = false;
        emit changed();
    }
    // Pomodoro
    reply = props.call(
        QStringLiteral("Get"), QString::fromLatin1(POMODORO),
        QStringLiteral("State"));
    if (reply.isValid())
        parsePomodoro(reply.value().toString());
    // Tasks
    reply = props.call(
        QStringLiteral("Get"), QString::fromLatin1(TODO),
        QStringLiteral("Items"));
    if (reply.isValid())
        parseTasks(reply.value().toString());
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
    // Microseconds on the wire, seconds in QML.
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
