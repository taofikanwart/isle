// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QTimer>

// A damped spring driving one animated value. Port of
// gnome-extension/src/spring.js: a spring can be retargeted mid-flight and
// keeps its velocity, so the island never jolts when the pointer changes its
// mind. Integrated in fixed substeps, so a late frame cannot make it explode.
class Spring : public QObject {
    Q_OBJECT
    Q_PROPERTY(qreal value READ value NOTIFY valueChanged)
    Q_PROPERTY(qreal target READ target WRITE setTarget NOTIFY targetChanged)
    Q_PROPERTY(qreal stiffness MEMBER m_stiffness)
    Q_PROPERTY(qreal damping MEMBER m_damping)
    // Stepped by the window's frame clock instead of a timer, so one step is
    // exactly one painted frame: a 16 ms timer beats against a 60 Hz vsync and
    // drops a frame whenever the two drift.
    Q_PROPERTY(bool drivenByFrames READ drivenByFrames WRITE setDrivenByFrames)

public:
    explicit Spring(QObject *parent = nullptr);

    qreal value() const { return m_value; }
    qreal target() const { return m_target; }

    void setTarget(qreal target);
    Q_INVOKABLE void reset(qreal value);

    bool drivenByFrames() const { return m_drivenByFrames; }
    void setDrivenByFrames(bool driven) { m_drivenByFrames = driven; }

    // One step of `dt` seconds, from the frame clock.
    Q_INVOKABLE void advance(qreal dt);

    bool settled() const;

signals:
    void valueChanged();
    void targetChanged();
    // A frame is needed to start moving (the frame clock only ticks when one
    // is painted).
    void wake();

private:
    void tick();

    static constexpr qreal MAX_STEP = 1.0 / 240.0;
    static constexpr qreal MAX_FRAME = 0.25;
    static constexpr qreal REST_DISTANCE = 0.25;
    static constexpr qreal REST_SPEED = 2.0;

    // ISLAND config from spring.js: ~3.5% overshoot, at rest by ~0.57 s.
    qreal m_stiffness = 155;
    qreal m_damping = 18;
    qreal m_value = 0;
    qreal m_target = 0;
    qreal m_velocity = 0;
    bool m_drivenByFrames = false;
    QTimer m_timer;
    QElapsedTimer m_clock;
};
