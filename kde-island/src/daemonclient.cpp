// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

#include "daemonclient.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QJsonDocument>
#include <QJsonObject>

namespace {
constexpr auto SERVICE = "io.github.zickrian.isle.Daemon";
constexpr auto PATH = "/io/github/zickrian/isle/Daemon";
constexpr auto MEDIA = "io.github.zickrian.isle.Media1";
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

void DaemonClient::onPropertiesChanged(const QString &interface,
                                       const QVariantMap &changed,
                                       const QStringList &invalidated) {
    Q_UNUSED(invalidated)
    if (interface != QLatin1String(MEDIA))
        return;
    const auto it = changed.constFind(QStringLiteral("NowPlaying"));
    if (it != changed.constEnd())
        parse(it->toString());
}

void DaemonClient::refresh() {
    QDBusInterface props(QString::fromLatin1(SERVICE), QString::fromLatin1(PATH),
                         QStringLiteral("org.freedesktop.DBus.Properties"));
    const QDBusReply<QVariant> reply = props.call(
        QStringLiteral("Get"), QString::fromLatin1(MEDIA),
        QStringLiteral("NowPlaying"));
    if (reply.isValid()) {
        m_connected = true;
        parse(reply.value().toString());
        return;
    }
    m_connected = false;
    emit changed();
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
