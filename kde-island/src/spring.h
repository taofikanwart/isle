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

public:
    explicit Spring(QObject *parent = nullptr);

    qreal value() const { return m_value; }
    qreal target() const { return m_target; }

    void setTarget(qreal target);
    Q_INVOKABLE void reset(qreal value);

    bool settled() const;

signals:
    void valueChanged();
    void targetChanged();

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
    QTimer m_timer;
    QElapsedTimer m_clock;
};
