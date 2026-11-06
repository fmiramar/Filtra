#include "MS20SK.hpp"
#include <cmath>
#include <algorithm>

namespace ms20 {

static constexpr double kPi = 3.141592653589793238462643383279502884;
static constexpr double kMaxResonanceK = 2.95; // Linear stability boundary is K = 3.0

// Control-rate frequency calculation (standard block-rate updates)
void MS20SK_next_k(MS20SK* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);

    const float sr = static_cast<float>(SAMPLERATE);
    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    // Read and clamp control-rate inputs
    float freqIn = IN0(1);
    float resIn = IN0(2);

    float clampedFreq = sc_clip(freqIn, minCutoff, nyquistLimit);
    float clampedRes = sc_clip(resIn, 0.0f, 1.0f);

    // Update filter coefficients if controls changed
    if (clampedFreq != unit->m_freq || clampedRes != unit->m_res) {
        unit->m_freq = clampedFreq;
        unit->m_res = clampedRes;

        // Feedback parameter K and loading damping factor (3 - K)
        const double K = static_cast<double>(clampedRes) * kMaxResonanceK;
        const double d1 = 3.0 - K;

        // Bilinear transform with continuous frequency prewarping
        const double w = std::tan(kPi * static_cast<double>(clampedFreq) / static_cast<double>(sr));
        const double c = 1.0 / w;
        const double c2 = c * c;

        // Denominator: D(s) = u^2 + (3 - K)*u + 1
        const double a0 = c2 + d1 * c + 1.0;
        const double inv_a0 = 1.0 / a0;

        unit->m_a1 = 2.0 * (1.0 - c2) * inv_a0;
        unit->m_a2 = (c2 - d1 * c + 1.0) * inv_a0;

        if (unit->m_mode == 0) {
            // Low-Pass: N_LP(s) = 1 (unity DC passband gain)
            unit->m_b0 = inv_a0;
            unit->m_b1 = 2.0 * inv_a0;
            unit->m_b2 = inv_a0;
        } else {
            // Authentic MS-20 High-Pass (lifted C2, grounded LP input):
            // N_HP(s) = u^2 + 2*u
            unit->m_b0 = (c2 + 2.0 * c) * inv_a0;
            unit->m_b1 = (-2.0 * c2) * inv_a0;
            unit->m_b2 = (c2 - 2.0 * c) * inv_a0;
        }
    }

    const double b0 = unit->m_b0;
    const double b1 = unit->m_b1;
    const double b2 = unit->m_b2;
    const double a1 = unit->m_a1;
    const double a2 = unit->m_a2;

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    // Transposed Direct Form II Difference Equation
    for (int i = 0; i < inNumSamples; ++i) {
        const double x = static_cast<double>(in[i]);
        const double y = b0 * x + s1;
        s1 = b1 * x - a1 * y + s2;
        s2 = b2 * x - a2 * y;
        out[i] = static_cast<float>(y);
    }

    // Flush subnormals / denormals to zero
    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

// Audio-rate frequency modulation (Low-Pass)
void MS20SK_next_lp_a(MS20SK* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* freqIn = IN(1);
    float* out = OUT(0);

    const float sr = static_cast<float>(SAMPLERATE);
    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);
    const double K = static_cast<double>(clampedRes) * kMaxResonanceK;
    const double d1 = 3.0 - K;

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
        const double w = std::tan(kPi * static_cast<double>(clampedFreq) / static_cast<double>(sr));
        const double c = 1.0 / w;
        const double c2 = c * c;

        const double a0 = c2 + d1 * c + 1.0;
        const double inv_a0 = 1.0 / a0;
        const double a1 = 2.0 * (1.0 - c2) * inv_a0;
        const double a2 = (c2 - d1 * c + 1.0) * inv_a0;
        const double b0 = inv_a0;
        const double b1 = 2.0 * inv_a0;
        const double b2 = inv_a0;

        const double x = static_cast<double>(in[i]);
        const double y = b0 * x + s1;
        s1 = b1 * x - a1 * y + s2;
        s2 = b2 * x - a2 * y;
        out[i] = static_cast<float>(y);
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

// Audio-rate frequency modulation (High-Pass)
void MS20SK_next_hp_a(MS20SK* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* freqIn = IN(1);
    float* out = OUT(0);

    const float sr = static_cast<float>(SAMPLERATE);
    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);
    const double K = static_cast<double>(clampedRes) * kMaxResonanceK;
    const double d1 = 3.0 - K;

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
        const double w = std::tan(kPi * static_cast<double>(clampedFreq) / static_cast<double>(sr));
        const double c = 1.0 / w;
        const double c2 = c * c;

        const double a0 = c2 + d1 * c + 1.0;
        const double inv_a0 = 1.0 / a0;
        const double a1 = 2.0 * (1.0 - c2) * inv_a0;
        const double a2 = (c2 - d1 * c + 1.0) * inv_a0;
        const double b0 = (c2 + 2.0 * c) * inv_a0;
        const double b1 = (-2.0 * c2) * inv_a0;
        const double b2 = (c2 - 2.0 * c) * inv_a0;

        const double x = static_cast<double>(in[i]);
        const double y = b0 * x + s1;
        s1 = b1 * x - a1 * y + s2;
        s2 = b2 * x - a2 * y;
        out[i] = static_cast<float>(y);
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

void MS20SK_Ctor(MS20SK* unit) {
    unit->m_s1 = 0.0;
    unit->m_s2 = 0.0;
    unit->m_freq = -1.0f;
    unit->m_res = -1.0f;
    unit->m_b0 = 0.0;
    unit->m_b1 = 0.0;
    unit->m_b2 = 0.0;
    unit->m_a1 = 0.0;
    unit->m_a2 = 0.0;

    const int mode = static_cast<int>(IN0(3));
    unit->m_mode = (mode != 0) ? 1 : 0;

    const bool isAudioRateFreq = (INRATE(1) == calc_FullRate);

    if (isAudioRateFreq) {
        if (unit->m_mode == 1) {
            SETCALC(MS20SK_next_hp_a);
            MS20SK_next_hp_a(unit, 1);
        } else {
            SETCALC(MS20SK_next_lp_a);
            MS20SK_next_lp_a(unit, 1);
        }
    } else {
        SETCALC(MS20SK_next_k);
        MS20SK_next_k(unit, 1);
    }
}

} // namespace ms20
