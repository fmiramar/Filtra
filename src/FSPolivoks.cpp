#include "FSPolivoks.hpp"
#include <cmath>
#include <algorithm>

namespace fs {

static inline double clamp_d(double val, double minVal, double maxVal) {
    return std::max(minVal, std::min(maxVal, val));
}

// Compute bilinear prewarped integrator coefficient g
static inline double calc_g(double freq, double sampleRate) {
    double fc = clamp_d(freq, 10.0, sampleRate * 0.49);
    return std::tan(M_PI * fc / sampleRate);
}

// Damping coefficient r from resonance parameter
// res in [0, 1]: res = 0 -> r = 2.0 (critically damped, Q = 0.5)
//                res = 1 -> r = 0.02 (high resonance, Q = 50.0)
static inline double calc_r(double res) {
    double r_clamped = clamp_d(res, 0.0, 1.0);
    return 2.0 * (1.0 - 0.99 * r_clamped);
}

void FSPolivoks_Ctor(FSPolivoks* unit) {
    unit->m_freq = IN0(1);
    unit->m_res = IN0(2);
    unit->m_mode = static_cast<int>(IN0(3));
    unit->m_drive = IN0(4);

    unit->m_s1 = 0.0;
    unit->m_s2 = 0.0;

    bool isAudioRateFreq = (INRATE(1) == calc_FullRate);

    if (unit->m_mode == 1) {
        // Band-Pass mode
        if (isAudioRateFreq) {
            SETCALC(FSPolivoks_next_bp_a);
        } else {
            SETCALC(FSPolivoks_next_bp_k);
        }
    } else {
        // Low-Pass mode (default)
        if (isAudioRateFreq) {
            SETCALC(FSPolivoks_next_lp_a);
        } else {
            SETCALC(FSPolivoks_next_lp_k);
        }
    }

    // Run first sample
    (unit->mCalcFunc)(unit, 1);
}

// Low-Pass: Control-rate frequency & resonance
void FSPolivoks_next_lp_k(FSPolivoks* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);

    double freq = IN0(1);
    double res = IN0(2);
    double drive = IN0(4);
    double sampleRate = SAMPLERATE;

    double g = calc_g(freq, sampleRate);
    double r = calc_r(res);
    double denom = 1.0 / (1.0 + r * g + g * g);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        double v_in = in[i] * drive;

        // Summing junction
        double v_sum = (v_in - (r + g) * s1 - s2) * denom;

        // Integrator outputs
        double v_bp = g * v_sum + s1;
        double v_lp = g * v_bp + s2;

        // State update (Trapezoidal integration)
        s1 = 2.0 * v_bp - s1;
        s2 = 2.0 * v_lp - s2;

        zapgremlins(s1);
        zapgremlins(s2);

        out[i] = static_cast<float>(v_lp);
    }

    unit->m_s1 = s1;
    unit->m_s2 = s2;
}

// Band-Pass: Control-rate frequency & resonance
void FSPolivoks_next_bp_k(FSPolivoks* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);

    double freq = IN0(1);
    double res = IN0(2);
    double drive = IN0(4);
    double sampleRate = SAMPLERATE;

    double g = calc_g(freq, sampleRate);
    double r = calc_r(res);
    double denom = 1.0 / (1.0 + r * g + g * g);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        double v_in = in[i] * drive;

        // Summing junction
        double v_sum = (v_in - (r + g) * s1 - s2) * denom;

        // Integrator outputs
        double v_bp = g * v_sum + s1;
        double v_lp = g * v_bp + s2;

        // State update (Trapezoidal integration)
        s1 = 2.0 * v_bp - s1;
        s2 = 2.0 * v_lp - s2;

        zapgremlins(s1);
        zapgremlins(s2);

        out[i] = static_cast<float>(v_bp);
    }

    unit->m_s1 = s1;
    unit->m_s2 = s2;
}

// Low-Pass: Audio-rate frequency
void FSPolivoks_next_lp_a(FSPolivoks* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* freqIn = IN(1);
    float* out = OUT(0);

    double res = IN0(2);
    double drive = IN0(4);
    double sampleRate = SAMPLERATE;

    double r = calc_r(res);
    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        double g = calc_g(freqIn[i], sampleRate);
        double denom = 1.0 / (1.0 + r * g + g * g);
        double v_in = in[i] * drive;

        double v_sum = (v_in - (r + g) * s1 - s2) * denom;
        double v_bp = g * v_sum + s1;
        double v_lp = g * v_bp + s2;

        s1 = 2.0 * v_bp - s1;
        s2 = 2.0 * v_lp - s2;

        zapgremlins(s1);
        zapgremlins(s2);

        out[i] = static_cast<float>(v_lp);
    }

    unit->m_s1 = s1;
    unit->m_s2 = s2;
}

// Band-Pass: Audio-rate frequency
void FSPolivoks_next_bp_a(FSPolivoks* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* freqIn = IN(1);
    float* out = OUT(0);

    double res = IN0(2);
    double drive = IN0(4);
    double sampleRate = SAMPLERATE;

    double r = calc_r(res);
    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        double g = calc_g(freqIn[i], sampleRate);
        double denom = 1.0 / (1.0 + r * g + g * g);
        double v_in = in[i] * drive;

        double v_sum = (v_in - (r + g) * s1 - s2) * denom;
        double v_bp = g * v_sum + s1;
        double v_lp = g * v_bp + s2;

        s1 = 2.0 * v_bp - s1;
        s2 = 2.0 * v_lp - s2;

        zapgremlins(s1);
        zapgremlins(s2);

        out[i] = static_cast<float>(v_bp);
    }

    unit->m_s1 = s1;
    unit->m_s2 = s2;
}

} // namespace fs
