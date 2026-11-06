#include "NLMS.hpp"
#include <cmath>
#include <algorithm>

namespace fs {

static inline double clamp_d(double val, double minVal, double maxVal) {
    return std::max(minVal, std::min(maxVal, val));
}

void NLMS_Ctor(NLMS* unit) {
    unit->m_bufIdx = 0;
    for (int k = 0; k < 32; ++k) {
        unit->m_xBuf[k] = 0.0;
        unit->m_weights[k] = 0.0;
    }

    SETCALC(NLMS_next);

    OUT0(0) = 0.0f;
    OUT0(1) = 0.0f;
}

void NLMS_next(NLMS* unit, int inNumSamples) {
    const float* refIn = IN(0);
    const float* desIn = IN(1);

    float* outY = OUT(0); // Estimated signal y[n]
    float* outE = OUT(1); // Residual error e[n]

    const double mu  = clamp_d(IN0(2), 0.0, 1.0);
    const double eps = clamp_d(IN0(3), 1e-6, 1.0);

    int idx = unit->m_bufIdx;
    double* xBuf = unit->m_xBuf;
    double* w = unit->m_weights;

    for (int i = 0; i < inNumSamples; ++i) {
        const double x = static_cast<double>(refIn[i]);
        const double d = static_cast<double>(desIn[i]);

        xBuf[idx] = x;

        // 1. FIR Filter Output & Input Vector Power
        double y = 0.0;
        double power = 0.0;

        for (int k = 0; k < 32; ++k) {
            const double tapX = xBuf[(idx - k) & 31];
            y += w[k] * tapX;
            power += tapX * tapX;
        }

        // 2. Error Signal
        const double e = d - y;

        // 3. Normalized LMS Weight Update
        if (mu > 0.0) {
            const double mu_eff = mu / (eps + power);
            const double step = mu_eff * e;

            for (int k = 0; k < 32; ++k) {
                const double tapX = xBuf[(idx - k) & 31];
                double newW = w[k] + step * tapX;
                // Leakage/clamping to guarantee absolute bounded BIBO stability
                w[k] = clamp_d(newW, -10.0, 10.0);
            }
        }

        outY[i] = static_cast<float>(y);
        outE[i] = static_cast<float>(e);

        idx = (idx + 1) & 31;
    }

    unit->m_bufIdx = idx;
}

} // namespace fs
