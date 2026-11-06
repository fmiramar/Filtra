#include "MS20TPT.hpp"
#include <cmath>
#include <algorithm>

namespace ms20 {

static constexpr double kPi = 3.141592653589793238462643383279502884;
static constexpr double kMaxResonanceK = 2.95; // Linear stability boundary is K = 3.0

static inline void updateCoefficients(MS20TPT* unit, float sr) {
    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    float freqIn = IN0(1);
    float resIn = IN0(2);

    float clampedFreq = sc_clip(freqIn, minCutoff, nyquistLimit);
    float clampedRes = sc_clip(resIn, 0.0f, 1.0f);

    if (clampedFreq != unit->m_freq || clampedRes != unit->m_res) {
        unit->m_freq = clampedFreq;
        unit->m_res = clampedRes;

        const double K = static_cast<double>(clampedRes) * kMaxResonanceK;
        const double g = std::tan(kPi * static_cast<double>(clampedFreq) / static_cast<double>(sr));
        unit->m_g = g;

        // Algebraic zero-delay inverse matrix: M = (I - g * A0)
        // With loading: det(M) = g^2 + (3 - K)*g + 1
        const double det = g * g + (3.0 - K) * g + 1.0;
        const double inv_det = 1.0 / det;

        unit->m_m00 = (1.0 - g * (K - 1.0)) * inv_det;
        unit->m_m01 = (g * (2.0 * K - 1.0)) * inv_det;
        unit->m_m10 = (-g) * inv_det;
        unit->m_m11 = (1.0 + 2.0 * g) * inv_det;

        if (unit->m_mode == 0) {
            // Low-pass: B0 = [-1, 0]^T
            unit->m_b00 = -g;
            unit->m_b10 = 0.0;
        } else {
            // Authentic MS-20 High-pass: B0 = [2K - 1, K - 1]^T
            unit->m_b00 = g * (2.0 * K - 1.0);
            unit->m_b10 = g * (K - 1.0);
        }
    }
}

void MS20TPT_next_lp(MS20TPT* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);
    const float sr = static_cast<float>(SAMPLERATE);

    updateCoefficients(unit, sr);

    const double b00 = unit->m_b00;
    const double m00 = unit->m_m00;
    const double m01 = unit->m_m01;
    const double m10 = unit->m_m10;
    const double m11 = unit->m_m11;

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    // Zero-delay loop: exact linear algebraic evaluation
    for (int i = 0; i < inNumSamples; ++i) {
        const double x = static_cast<double>(in[i]);
        const double r1 = b00 * x + s1;
        const double r2 = s2;

        const double vc1 = m00 * r1 + m01 * r2;
        const double vc2 = m10 * r1 + m11 * r2;

        out[i] = static_cast<float>(vc2);

        // Trapezoidal integrator state update: s[n] = 2 * v[n] - s[n-1]
        s1 = 2.0 * vc1 - s1;
        s2 = 2.0 * vc2 - s2;
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

void MS20TPT_next_hp(MS20TPT* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);
    const float sr = static_cast<float>(SAMPLERATE);

    updateCoefficients(unit, sr);

    const double b00 = unit->m_b00;
    const double b10 = unit->m_b10;
    const double m00 = unit->m_m00;
    const double m01 = unit->m_m01;
    const double m10 = unit->m_m10;
    const double m11 = unit->m_m11;

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    // Zero-delay loop: exact linear algebraic evaluation for authentic MS-20 HP
    for (int i = 0; i < inNumSamples; ++i) {
        const double x = static_cast<double>(in[i]);
        const double r1 = b00 * x + s1;
        const double r2 = b10 * x + s2;

        const double vc1 = m00 * r1 + m01 * r2;
        const double vc2 = m10 * r1 + m11 * r2;

        // Output: V3 = vc2 + Vin
        out[i] = static_cast<float>(vc2 + x);

        // Trapezoidal integrator state update: s[n] = 2 * v[n] - s[n-1]
        s1 = 2.0 * vc1 - s1;
        s2 = 2.0 * vc2 - s2;
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

void MS20TPT_next_lp_a(MS20TPT* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* freqIn = IN(1);
    float* out = OUT(0);
    const float sr = static_cast<float>(SAMPLERATE);

    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);
    const double K = static_cast<double>(clampedRes) * kMaxResonanceK;

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
        const double g = std::tan(kPi * static_cast<double>(clampedFreq) / static_cast<double>(sr));
        const double det = g * g + (3.0 - K) * g + 1.0;
        const double inv_det = 1.0 / det;

        const double m00 = (1.0 - g * (K - 1.0)) * inv_det;
        const double m01 = (g * (2.0 * K - 1.0)) * inv_det;
        const double m10 = (-g) * inv_det;
        const double m11 = (1.0 + 2.0 * g) * inv_det;

        const double x = static_cast<double>(in[i]);
        const double r1 = -g * x + s1;
        const double r2 = s2;

        const double vc1 = m00 * r1 + m01 * r2;
        const double vc2 = m10 * r1 + m11 * r2;

        out[i] = static_cast<float>(vc2);

        s1 = 2.0 * vc1 - s1;
        s2 = 2.0 * vc2 - s2;
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

void MS20TPT_next_hp_a(MS20TPT* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* freqIn = IN(1);
    float* out = OUT(0);
    const float sr = static_cast<float>(SAMPLERATE);

    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);
    const double K = static_cast<double>(clampedRes) * kMaxResonanceK;

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
        const double g = std::tan(kPi * static_cast<double>(clampedFreq) / static_cast<double>(sr));
        const double det = g * g + (3.0 - K) * g + 1.0;
        const double inv_det = 1.0 / det;

        const double m00 = (1.0 - g * (K - 1.0)) * inv_det;
        const double m01 = (g * (2.0 * K - 1.0)) * inv_det;
        const double m10 = (-g) * inv_det;
        const double m11 = (1.0 + 2.0 * g) * inv_det;

        const double b00 = g * (2.0 * K - 1.0);
        const double b10 = g * (K - 1.0);

        const double x = static_cast<double>(in[i]);
        const double r1 = b00 * x + s1;
        const double r2 = b10 * x + s2;

        const double vc1 = m00 * r1 + m01 * r2;
        const double vc2 = m10 * r1 + m11 * r2;

        out[i] = static_cast<float>(vc2 + x);

        s1 = 2.0 * vc1 - s1;
        s2 = 2.0 * vc2 - s2;
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

void MS20TPT_Ctor(MS20TPT* unit) {
    unit->m_s1 = 0.0;
    unit->m_s2 = 0.0;
    unit->m_freq = -1.0f;
    unit->m_res = -1.0f;
    unit->m_g = 0.0;
    unit->m_m00 = 0.0;
    unit->m_m01 = 0.0;
    unit->m_m10 = 0.0;
    unit->m_m11 = 0.0;
    unit->m_b00 = 0.0;
    unit->m_b10 = 0.0;

    const int mode = static_cast<int>(IN0(3));
    unit->m_mode = (mode != 0) ? 1 : 0;

    const bool isAudioRateFreq = (INRATE(1) == calc_FullRate);

    if (unit->m_mode == 1) {
        if (isAudioRateFreq) {
            SETCALC(MS20TPT_next_hp_a);
            MS20TPT_next_hp_a(unit, 1);
        } else {
            SETCALC(MS20TPT_next_hp);
            MS20TPT_next_hp(unit, 1);
        }
    } else {
        if (isAudioRateFreq) {
            SETCALC(MS20TPT_next_lp_a);
            MS20TPT_next_lp_a(unit, 1);
        } else {
            SETCALC(MS20TPT_next_lp);
            MS20TPT_next_lp(unit, 1);
        }
    }
}

} // namespace ms20
