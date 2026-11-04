// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>

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

    // --- pomodoro -----------------------------------------------------------
    Q_PROPERTY(QString pomodoroPhase READ pomodoroPhase NOTIFY pomodoroChanged)
    Q_PROPERTY(bool pomodoroRunning READ pomodoroRunning NOTIFY pomodoroChanged)
    Q_PROPERTY(double pomodoroRemaining READ pomodoroRemaining NOTIFY pomodoroChanged)
    Q_PROPERTY(double pomodoroDuration READ pomodoroDuration NOTIFY pomodoroChanged)
    Q_PROPERTY(int pomodoroSessions READ pomodoroSessions NOTIFY pomodoroChanged)

    // --- todo ---------------------------------------------------------------
    // List of {id, title, done}
    Q_PROPERTY(QVariantList tasks READ tasks NOTIFY tasksChanged)

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

    QString pomodoroPhase() const { return m_pomodoroPhase; }
    bool pomodoroRunning() const { return m_pomodoroRunning; }
    double pomodoroRemaining() const;
    double pomodoroDuration() const { return m_pomodoroDuration; }
    int pomodoroSessions() const { return m_pomodoroSessions; }

    QVariantList tasks() const { return m_tasks; }

    Q_INVOKABLE void playPause();
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();

    // Pomodoro actions
    Q_INVOKABLE void pomodoroToggle();
    Q_INVOKABLE void pomodoroStop();
    Q_INVOKABLE void pomodoroSkip();

    // Todo actions
    Q_INVOKABLE void todoAdd(const QString &text);
    Q_INVOKABLE void todoSetDone(quint64 id, bool done);
    Q_INVOKABLE void todoRename(quint64 id, const QString &text);
    Q_INVOKABLE void todoRemove(quint64 id);

signals:
    void changed();
    void pomodoroChanged();
    void tasksChanged();

private slots:
    void onPropertiesChanged(const QString &interface,
                             const QVariantMap &changed,
                             const QStringList &invalidated);

private:
    void refresh();
    void parse(const QString &json);
    void parsePomodoro(const QString &json);
    void parseTasks(const QString &json);

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

    // Pomodoro
    QString m_pomodoroPhase = QStringLiteral("idle");
    bool m_pomodoroRunning = false;
    double m_pomodoroRemaining = 25 * 60;
    double m_pomodoroDuration = 25 * 60;
    qint64 m_pomodoroEndsAtMs = 0;
    int m_pomodoroSessions = 0;

    // Tasks
    QVariantList m_tasks;
};
