#include "Dispersion.hpp"
#include <cmath>
#include <algorithm>

namespace fs {

static constexpr double kPi = 3.14159265358979323846;

static inline double clamp_d(double val, double minVal, double maxVal) {
    return std::max(minVal, std::min(maxVal, val));
}

static const double kOffsets[4] = { -0.75, -0.25, 0.25, 0.75 };

void Dispersion_Ctor(Dispersion* unit) {
    unit->m_center = IN0(1);
    unit->m_spread = IN0(2);
    unit->m_q = IN0(3);

    for (int k = 0; k < 4; ++k) {
        unit->m_sections[k].init();
    }

    bool isAudioRateFreq = (INRATE(1) == calc_FullRate);
    if (isAudioRateFreq) {
        SETCALC(Dispersion_next_a);
    } else {
        SETCALC(Dispersion_next_k);
    }

    OUT0(0) = 0.0f;
}

void Dispersion_next_k(Dispersion* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);

    double center = clamp_d(IN0(1), 20.0, SAMPLERATE * 0.45);
    double spread = clamp_d(IN0(2), 0.0, 4.0);
    double q = clamp_d(IN0(3), 0.1, 25.0);
    double sampleRate = SAMPLERATE;

    double R = 1.0 / q;
    double g[4];
    double denom[4];

    for (int k = 0; k < 4; ++k) {
        double fk = center * std::pow(2.0, kOffsets[k] * spread);
        fk = clamp_d(fk, 10.0, sampleRate * 0.49);
        g[k] = std::tan(kPi * fk / sampleRate);
        denom[k] = 1.0 / (1.0 + R * g[k] + g[k] * g[k]);
    }

    for (int i = 0; i < inNumSamples; ++i) {
        double val = in[i];
        val = unit->m_sections[0].process(val, g[0], R, denom[0]);
        val = unit->m_sections[1].process(val, g[1], R, denom[1]);
        val = unit->m_sections[2].process(val, g[2], R, denom[2]);
        val = unit->m_sections[3].process(val, g[3], R, denom[3]);
        out[i] = static_cast<float>(val);
    }
}

void Dispersion_next_a(Dispersion* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* centerIn = IN(1);
    float* out = OUT(0);

    double spread = clamp_d(IN0(2), 0.0, 4.0);
    double q = clamp_d(IN0(3), 0.1, 25.0);
    double sampleRate = SAMPLERATE;
    double R = 1.0 / q;

    for (int i = 0; i < inNumSamples; ++i) {
        double center = clamp_d(centerIn[i], 20.0, sampleRate * 0.45);
        double g[4];
        double denom[4];

        for (int k = 0; k < 4; ++k) {
            double fk = center * std::pow(2.0, kOffsets[k] * spread);
            fk = clamp_d(fk, 10.0, sampleRate * 0.49);
            g[k] = std::tan(kPi * fk / sampleRate);
            denom[k] = 1.0 / (1.0 + R * g[k] + g[k] * g[k]);
        }

        double val = in[i];
        val = unit->m_sections[0].process(val, g[0], R, denom[0]);
        val = unit->m_sections[1].process(val, g[1], R, denom[1]);
        val = unit->m_sections[2].process(val, g[2], R, denom[2]);
        val = unit->m_sections[3].process(val, g[3], R, denom[3]);
        out[i] = static_cast<float>(val);
    }
}

} // namespace fs
