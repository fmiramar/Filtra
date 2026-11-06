#pragma once

#include "SC_PlugIn.h"

namespace fs {

// NLMS: Real-Time Adaptive Normalized Least-Mean-Squares FIR Filter
// Reference: Haykin, Adaptive Filter Theory; Widrow & Stearns.
// Adapts a 32-tap FIR weight vector in real time to estimate a target desired signal
// and minimize residual error: e[n] = desired[n] - y[n].
// Outputs: [0] = estimated signal y[n], [1] = residual error e[n].
struct NLMS : public Unit {
    float m_mu;
    float m_eps;

    int m_bufIdx;
    double m_xBuf[32]; // Circular delay line buffer
    double m_weights[32]; // Adaptive FIR filter tap weights
};

void NLMS_Ctor(NLMS* unit);
void NLMS_next(NLMS* unit, int inNumSamples);

} // namespace fs
