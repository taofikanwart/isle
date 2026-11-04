// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

#pragma once

#include <QDBusMessage>
#include <QObject>
#include <QSettings>
#include <QString>
#include <QVariantList>

class DaemonClient : public QObject {
    Q_OBJECT

    // --- media --------------------------------------------------------------
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
    Q_PROPERTY(double position READ position NOTIFY changed)
    Q_PROPERTY(double duration READ duration NOTIFY changed)

    // --- pomodoro -----------------------------------------------------------
    Q_PROPERTY(QString pomodoroPhase READ pomodoroPhase NOTIFY pomodoroChanged)
    Q_PROPERTY(bool pomodoroRunning READ pomodoroRunning NOTIFY pomodoroChanged)
    Q_PROPERTY(double pomodoroRemaining READ pomodoroRemaining NOTIFY pomodoroChanged)
    Q_PROPERTY(double pomodoroDuration READ pomodoroDuration NOTIFY pomodoroChanged)
    Q_PROPERTY(int pomodoroSessions READ pomodoroSessions NOTIFY pomodoroChanged)

    // --- todo ---------------------------------------------------------------
    Q_PROPERTY(QVariantList tasks READ tasks NOTIFY tasksChanged)

    // --- clipboard ----------------------------------------------------------
    Q_PROPERTY(QVariantList clips READ clips NOTIFY clipsChanged)

    // --- calendar -----------------------------------------------------------
    Q_PROPERTY(QVariantList events READ events NOTIFY eventsChanged)

    // --- notifications ------------------------------------------------------
    Q_PROPERTY(QVariantList notifications READ notifications NOTIFY notificationsChanged)
    Q_PROPERTY(int unreadNotificationsCount READ unreadNotificationsCount NOTIFY notificationsChanged)

    // --- settings (persistent via QSettings ~/.config/isle/island.conf) ----
    Q_PROPERTY(QString themeName READ themeName WRITE setThemeName NOTIFY settingsChanged)
    Q_PROPERTY(int glassTint READ glassTint WRITE setGlassTint NOTIFY settingsChanged)
    Q_PROPERTY(bool inBar READ inBar WRITE setInBar NOTIFY settingsChanged)
    Q_PROPERTY(int notchDepth READ notchDepth WRITE setNotchDepth NOTIFY settingsChanged)

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
    QVariantList clips() const { return m_clips; }
    QVariantList events() const { return m_events; }
    QVariantList notifications() const { return m_notifications; }
    int unreadNotificationsCount() const { return m_notifications.size(); }

    // Settings getters & setters
    QString themeName() const { return m_themeName; }
    void setThemeName(const QString &val);
    int glassTint() const { return m_glassTint; }
    void setGlassTint(int val);
    bool inBar() const { return m_inBar; }
    void setInBar(bool val);
    int notchDepth() const { return m_notchDepth; }
    void setNotchDepth(int val);

    // Media actions
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

    // Clipboard actions
    Q_INVOKABLE void clipCopy(const QString &text);
    Q_INVOKABLE void clipSetPinned(quint64 id, bool pinned);
    Q_INVOKABLE void clipRemove(quint64 id);
    Q_INVOKABLE void clipClear();

    // Calendar actions
    Q_INVOKABLE void calendarAdd(const QString &date, const QString &title);
    Q_INVOKABLE void calendarRemove(quint64 id);

    // Notification actions
    Q_INVOKABLE void notificationDismiss(int index);
    Q_INVOKABLE void notificationClearAll();
    void appendNotification(const QString &app, const QString &summary, const QString &text);

signals:
    void changed();
    void pomodoroChanged();
    void tasksChanged();
    void clipsChanged();
    void eventsChanged();
    void notificationsChanged();
    void settingsChanged();
    void notificationArrived(const QString &summary, const QString &body, const QString &app);

private slots:
    void onPropertiesChanged(const QString &interface,
                             const QVariantMap &changed,
                             const QStringList &invalidated);
    void onClipboardChanged();

private:
    void refresh();
    void parse(const QString &json);
    void parsePomodoro(const QString &json);
    void parseTasks(const QString &json);
    void parseClips(const QString &json);
    void parseEvents(const QString &json);

    void setupNotificationListener();
    void loadSettings();
    void saveSettings();

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

    // Tasks, Clips, Events, Notifications
    QVariantList m_tasks;
    QVariantList m_clips;
    QVariantList m_events;
    QVariantList m_notifications;
    quint64 m_nextNotifId = 1;

    // Clipboard loop protection
    QString m_lastCopiedText;

    // Settings
    QString m_themeName = QStringLiteral("black");
    int m_glassTint = 0;
    bool m_inBar = true;
    int m_notchDepth = 30;
};
