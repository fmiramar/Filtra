#include "FSSteiner.hpp"
#include <cmath>
#include <algorithm>

namespace fs {

static constexpr double kPi = 3.141592653589793238462643383279502884;
static constexpr double kMaxK = 3.6; // K = 3.0 is self-oscillation threshold; up to 3.6 for saturated limit cycle

// -------------------------------------------------------------
// Core Steiner-Parker TPT Solver Step
// -------------------------------------------------------------
static inline void FSSteiner_step(int mode, double x, double g, double K, double drive,
                                  double& s1, double& s2, double& out)
{
    const double det0 = g * g + 3.0 * g + 1.0;
    const double inv_det0 = 1.0 / det0;

    const double m00 = (1.0 + g) * inv_det0;
    const double m01 = (-g) * inv_det0;
    const double m10 = (-g) * inv_det0;
    const double m11 = (1.0 + 2.0 * g) * inv_det0;

    const double gamma = g * inv_det0;
    const double g_m0_f_0 = g * (2.0 + g) * inv_det0;
    const double g_m0_f_1 = g * inv_det0;

    double b00 = 0.0;
    double b10 = 0.0;
    double v_open = 0.0;
    double sign_fb = 1.0;

    if (mode == 1) { // Band-Pass
        b00 = 2.0 * g;
        b10 = 1.0 * g;
        sign_fb = 1.0;
    } else if (mode == 2) { // High-Pass
        b00 = -g;
        b10 = -g;
        sign_fb = 1.0;
    } else { // Low-Pass (mode 0)
        b00 = -g;
        b10 = 0.0;
        sign_fb = -1.0;
    }

    const double r1 = b00 * x + s1;
    const double r2 = b10 * x + s2;

    const double vc1_open = m00 * r1 + m01 * r2;
    const double vc2_open = m10 * r1 + m11 * r2;

    if (mode == 1) {
        v_open = vc2_open;
    } else if (mode == 2) {
        v_open = vc2_open + x;
    } else {
        v_open = -vc2_open;
    }

    double v_out = 0.0;

    if (drive <= 0.001) {
        // Pure linear small-signal closed-loop solution
        const double den_lin = 1.0 - gamma * K;
        v_out = (std::abs(den_lin) > 1.0e-5) ? (v_open / den_lin) : v_open;
    } else {
        // Nonlinear diode limiter solution (Yasunori Hirakawa / YuSynth D9/D10 anti-parallel diodes)
        const double alpha = drive;
        const double inv_alpha = 1.0 / alpha;

        // Initial guess: linear solution or damped v_open
        const double den_lin = 1.0 - gamma * K;
        v_out = (den_lin > 0.05) ? (v_open / den_lin) : v_open;

        constexpr int kMaxIter = 4;
        constexpr double kTol = 1.0e-6;

        for (int it = 0; it < kMaxIter; ++it) {
            const double t = std::tanh(alpha * v_out);
            const double f_nl = t * inv_alpha;
            const double df_nl = 1.0 - t * t;

            const double F = v_out - v_open - gamma * K * f_nl;
            const double dF = 1.0 - gamma * K * df_nl;

            const double step = F / dF;
            v_out -= step;

            if (std::abs(step) < kTol) {
                break;
            }
        }
    }

    // Full state vector reconstruction with converged feedback
    double v_fb = 0.0;
    if (drive <= 0.001) {
        v_fb = sign_fb * K * v_out;
    } else {
        v_fb = sign_fb * K * (std::tanh(drive * v_out) / drive);
    }

    const double vc1 = vc1_open + g_m0_f_0 * v_fb;
    const double vc2 = vc2_open + g_m0_f_1 * v_fb;

    // Trapezoidal capacitor state updates
    s1 = 2.0 * vc1 - s1;
    s2 = 2.0 * vc2 - s2;

    out = v_out;
}

// -------------------------------------------------------------
// Control-Rate Calculation Loops (k-rate)
// -------------------------------------------------------------

void FSSteiner_next_lp_k(FSSteiner* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);
    const float sr = static_cast<float>(SAMPLERATE);
    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    const float clampedFreq = sc_clip(IN0(1), minCutoff, nyquistLimit);
    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);
    const float clampedDrive = sc_clip(IN0(4), 0.0f, 20.0f);

    const double fc = static_cast<double>(clampedFreq);
    const double K = static_cast<double>(clampedRes) * kMaxK;
    const double drive = static_cast<double>(clampedDrive);
    const double g = std::tan(kPi * fc / static_cast<double>(sr));

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        double y;
        FSSteiner_step(0, static_cast<double>(in[i]), g, K, drive, s1, s2, y);
        out[i] = static_cast<float>(y);
    }

    s1 = std::clamp(s1, -100.0, 100.0);
    s2 = std::clamp(s2, -100.0, 100.0);
    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

void FSSteiner_next_bp_k(FSSteiner* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);
    const float sr = static_cast<float>(SAMPLERATE);
    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    const float clampedFreq = sc_clip(IN0(1), minCutoff, nyquistLimit);
    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);
    const float clampedDrive = sc_clip(IN0(4), 0.0f, 20.0f);

    const double fc = static_cast<double>(clampedFreq);
    const double K = static_cast<double>(clampedRes) * kMaxK;
    const double drive = static_cast<double>(clampedDrive);
    const double g = std::tan(kPi * fc / static_cast<double>(sr));

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        double y;
        FSSteiner_step(1, static_cast<double>(in[i]), g, K, drive, s1, s2, y);
        out[i] = static_cast<float>(y);
    }

    s1 = std::clamp(s1, -100.0, 100.0);
    s2 = std::clamp(s2, -100.0, 100.0);
    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

void FSSteiner_next_hp_k(FSSteiner* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);
    const float sr = static_cast<float>(SAMPLERATE);
    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    const float clampedFreq = sc_clip(IN0(1), minCutoff, nyquistLimit);
    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);
    const float clampedDrive = sc_clip(IN0(4), 0.0f, 20.0f);

    const double fc = static_cast<double>(clampedFreq);
    const double K = static_cast<double>(clampedRes) * kMaxK;
    const double drive = static_cast<double>(clampedDrive);
    const double g = std::tan(kPi * fc / static_cast<double>(sr));

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        double y;
        FSSteiner_step(2, static_cast<double>(in[i]), g, K, drive, s1, s2, y);
        out[i] = static_cast<float>(y);
    }

    s1 = std::clamp(s1, -100.0, 100.0);
    s2 = std::clamp(s2, -100.0, 100.0);
    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

// -------------------------------------------------------------
// Audio-Rate Calculation Loops (a-rate FM)
// -------------------------------------------------------------

void FSSteiner_next_lp_a(FSSteiner* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* freqIn = IN(1);
    float* out = OUT(0);
    const float sr = static_cast<float>(SAMPLERATE);
    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);
    const float clampedDrive = sc_clip(IN0(4), 0.0f, 20.0f);
    const double K = static_cast<double>(clampedRes) * kMaxK;
    const double drive = static_cast<double>(clampedDrive);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
        const double fc = static_cast<double>(clampedFreq);
        const double g = std::tan(kPi * fc / static_cast<double>(sr));

        double y;
        FSSteiner_step(0, static_cast<double>(in[i]), g, K, drive, s1, s2, y);
        out[i] = static_cast<float>(y);
    }

    s1 = std::clamp(s1, -100.0, 100.0);
    s2 = std::clamp(s2, -100.0, 100.0);
    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

void FSSteiner_next_bp_a(FSSteiner* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* freqIn = IN(1);
    float* out = OUT(0);
    const float sr = static_cast<float>(SAMPLERATE);
    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);
    const float clampedDrive = sc_clip(IN0(4), 0.0f, 20.0f);
    const double K = static_cast<double>(clampedRes) * kMaxK;
    const double drive = static_cast<double>(clampedDrive);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
        const double fc = static_cast<double>(clampedFreq);
        const double g = std::tan(kPi * fc / static_cast<double>(sr));

        double y;
        FSSteiner_step(1, static_cast<double>(in[i]), g, K, drive, s1, s2, y);
        out[i] = static_cast<float>(y);
    }

    s1 = std::clamp(s1, -100.0, 100.0);
    s2 = std::clamp(s2, -100.0, 100.0);
    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

void FSSteiner_next_hp_a(FSSteiner* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* freqIn = IN(1);
    float* out = OUT(0);
    const float sr = static_cast<float>(SAMPLERATE);
    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);
    const float clampedDrive = sc_clip(IN0(4), 0.0f, 20.0f);
    const double K = static_cast<double>(clampedRes) * kMaxK;
    const double drive = static_cast<double>(clampedDrive);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
        const double fc = static_cast<double>(clampedFreq);
        const double g = std::tan(kPi * fc / static_cast<double>(sr));

        double y;
        FSSteiner_step(2, static_cast<double>(in[i]), g, K, drive, s1, s2, y);
        out[i] = static_cast<float>(y);
    }

    s1 = std::clamp(s1, -100.0, 100.0);
    s2 = std::clamp(s2, -100.0, 100.0);
    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

// -------------------------------------------------------------
// Constructor
// -------------------------------------------------------------

void FSSteiner_Ctor(FSSteiner* unit) {
    unit->m_s1 = 0.0;
    unit->m_s2 = 0.0;
    unit->m_freq = -1.0f;
    unit->m_res = -1.0f;
    unit->m_drive = 1.0f;

    const int mode = static_cast<int>(IN0(3));
    unit->m_mode = (mode >= 0 && mode <= 2) ? mode : 0;

    const bool isAudioRateFreq = (INRATE(1) == calc_FullRate);

    switch (unit->m_mode) {
        case 1: // Band-Pass
            if (isAudioRateFreq) {
                SETCALC(FSSteiner_next_bp_a);
                FSSteiner_next_bp_a(unit, 1);
            } else {
                SETCALC(FSSteiner_next_bp_k);
                FSSteiner_next_bp_k(unit, 1);
            }
            break;

        case 2: // High-Pass
            if (isAudioRateFreq) {
                SETCALC(FSSteiner_next_hp_a);
                FSSteiner_next_hp_a(unit, 1);
            } else {
                SETCALC(FSSteiner_next_hp_k);
                FSSteiner_next_hp_k(unit, 1);
            }
            break;

        case 0: // Low-Pass (default)
        default:
            if (isAudioRateFreq) {
                SETCALC(FSSteiner_next_lp_a);
                FSSteiner_next_lp_a(unit, 1);
            } else {
                SETCALC(FSSteiner_next_lp_k);
                FSSteiner_next_lp_k(unit, 1);
            }
            break;
    }
}

} // namespace fs
