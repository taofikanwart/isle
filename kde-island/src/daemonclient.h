// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

#pragma once

#include <QObject>
#include <QString>

// A thin client for isled's Media1 interface. Every property is a JSON string
// on the bus (see gnome-extension/src/daemon.js); this parses NowPlaying into
// the handful of fields the compact island and the media page show.
class DaemonClient : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool connected READ connected NOTIFY changed)
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(QString title READ title NOTIFY changed)
    Q_PROPERTY(QString artist READ artist NOTIFY changed)
    Q_PROPERTY(QString album READ album NOTIFY changed)
    Q_PROPERTY(QString artPath READ artPath NOTIFY changed)
    Q_PROPERTY(bool playing READ playing NOTIFY changed)
    Q_PROPERTY(bool canPlayPause READ canPlayPause NOTIFY changed)
    Q_PROPERTY(bool canGoNext READ canGoNext NOTIFY changed)
    Q_PROPERTY(bool canGoPrevious READ canGoPrevious NOTIFY changed)
    // Seconds, from the last position isled reported.
    Q_PROPERTY(double position READ position NOTIFY changed)
    Q_PROPERTY(double duration READ duration NOTIFY changed)

public:
    explicit DaemonClient(QObject *parent = nullptr);

    bool connected() const { return m_connected; }
    bool available() const { return m_available; }
    QString title() const { return m_title; }
    QString artist() const { return m_artist; }
    QString album() const { return m_album; }
    QString artPath() const { return m_artPath; }
    bool playing() const { return m_playing; }
    bool canPlayPause() const { return m_canPlayPause; }
    bool canGoNext() const { return m_canGoNext; }
    bool canGoPrevious() const { return m_canGoPrevious; }
    double position() const { return m_position; }
    double duration() const { return m_duration; }

    Q_INVOKABLE void playPause();
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();

signals:
    void changed();

private slots:
    void onPropertiesChanged(const QString &interface,
                             const QVariantMap &changed,
                             const QStringList &invalidated);

private:
    void refresh();
    void parse(const QString &json);

    bool m_connected = false;
    bool m_available = false;
    QString m_title;
    QString m_artist;
    QString m_album;
    QString m_artPath;
    bool m_playing = false;
    bool m_canPlayPause = false;
    bool m_canGoNext = false;
    bool m_canGoPrevious = false;
    double m_position = 0;
    double m_duration = 0;
};
