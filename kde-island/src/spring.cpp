// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 zickrian

#include "spring.h"

#include <algorithm>
#include <cmath>

Spring::Spring(QObject *parent)
    : QObject(parent) {
    // The display refreshes at 60 Hz; ticking faster only queues updates the
    // compositor throws away, and each one costs a shape change.
    m_timer.setInterval(16);
    connect(&m_timer, &QTimer::timeout, this, &Spring::tick);
}

bool Spring::settled() const {
    return std::abs(m_value - m_target) < REST_DISTANCE &&
        std::abs(m_velocity) < REST_SPEED;
}

void Spring::setTarget(qreal target) {
    if (qFuzzyCompare(m_target, target))
        return;
    m_target = target;
    emit targetChanged();
    if (settled())
        return;
    if (m_drivenByFrames)
        emit wake();
    else {
        m_clock.start();
        m_timer.start();
    }
}

void Spring::reset(qreal value) {
    m_value = m_target = value;
    m_velocity = 0;
    m_timer.stop();
    emit valueChanged();
}

void Spring::advance(qreal dt) {
    if (settled())
        return;
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
    }
    emit valueChanged();
}

void Spring::tick() {
    const qreal dt = m_clock.isValid() ? m_clock.restart() / 1000.0 : 0.016;
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
