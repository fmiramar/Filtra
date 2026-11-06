#include "FSWasp.hpp"
#include <cmath>
#include <algorithm>

namespace fs {

static constexpr double kPi = 3.141592653589793238462643383279502884;

// Physical component parameters for EDP Wasp VCF (Doepfer revision, Table 1 in Köper et al. 2022)
static constexpr double kRres = 50.0e3;
static constexpr double kR13  = 1.0e6;
static constexpr double kR14  = 1.0e3;
static constexpr double kR15  = 100.0e3;
static constexpr double kR3   = 27.0e3;
static constexpr double kR4   = 27.0e3;
static constexpr double kC7   = 0.22e-6;
static constexpr double kR2C2 = 2.7e-6; // R2 * C2 = 27 kOhm * 100 pF

// Analytical damping factor kres = 1 / Q = Re(H1(j*wc)) + R2*C2*wc (Köper et al., eq. 25-32)
static inline double compute_kres(double fc, double rho) {
    const double wc = 2.0 * kPi * fc;
    const double R_prime = rho * kRres + kR14;
    const double b1 = kR3 * (1.0 - rho) * kRres * (kR13 + kR15) * kC7;
    const double b0 = kR3 * (kRres + kR13 + kR14 + kR15);
    const double a1 = (R_prime * (1.0 - rho) * kRres + (kRres + kR14) * kR4) * (kR13 + kR15) * kC7;
    const double a0 = (R_prime + kR4) * (kRres + kR13 + kR14 + kR15) - (R_prime * R_prime);

    const double wc2 = wc * wc;
    const double den = a0 * a0 + a1 * a1 * wc2;
    const double re_H1 = (b0 * a0 + b1 * a1 * wc2) / den;
    const double kres = re_H1 + kR2C2 * wc;
    return (kres > 0.005) ? kres : 0.005; // Maintain strictly positive damping
}

// Single-sample core state-variable solver (Topology-Preserving Transform / Trapezoidal)
static inline void FSWasp_step(double in_sample, double g, double kres,
                               double& s1, double& s2,
                               double& out_lp, double& out_bp, double& out_hp)
{
    const double inv_den = 1.0 / (1.0 + kres * g + g * g);
    // Summing node (inverting amplifier IC1)
    const double v_hp = -(in_sample + (kres + g) * s1 + s2) * inv_den;
    // First integrator (OTA + CMOS inverter IC2/IC3)
    const double v_bp = g * v_hp + s1;
    // Second integrator (OTA + CMOS inverter IC4/IC5)
    const double v_lp = g * v_bp + s2;

    // Trapezoidal state updates
    s1 = 2.0 * v_bp - s1;
    s2 = 2.0 * v_lp - s2;

    // Phase-normalized outputs (0 dB in-phase passband at DC for LP and at Nyquist for HP)
    out_lp = -v_lp;
    out_bp = v_bp;
    out_hp = -v_hp;
}

// -------------------------------------------------------------
// Control-rate frequency modulation (k-rate)
// -------------------------------------------------------------

void FSWasp_next_lp_k(FSWasp* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);
    const float sr = static_cast<float>(SAMPLERATE);
    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    const float clampedFreq = sc_clip(IN0(1), minCutoff, nyquistLimit);
    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);

    const double fc = static_cast<double>(clampedFreq);
    const double rho = static_cast<double>(clampedRes);
    const double g = std::tan(kPi * fc / static_cast<double>(sr));
    const double kres = compute_kres(fc, rho);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        double lp, bp, hp;
        FSWasp_step(static_cast<double>(in[i]), g, kres, s1, s2, lp, bp, hp);
        out[i] = static_cast<float>(lp);
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

void FSWasp_next_bp_k(FSWasp* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);
    const float sr = static_cast<float>(SAMPLERATE);
    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    const float clampedFreq = sc_clip(IN0(1), minCutoff, nyquistLimit);
    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);

    const double fc = static_cast<double>(clampedFreq);
    const double rho = static_cast<double>(clampedRes);
    const double g = std::tan(kPi * fc / static_cast<double>(sr));
    const double kres = compute_kres(fc, rho);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        double lp, bp, hp;
        FSWasp_step(static_cast<double>(in[i]), g, kres, s1, s2, lp, bp, hp);
        out[i] = static_cast<float>(bp);
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

void FSWasp_next_hp_k(FSWasp* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);
    const float sr = static_cast<float>(SAMPLERATE);
    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    const float clampedFreq = sc_clip(IN0(1), minCutoff, nyquistLimit);
    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);

    const double fc = static_cast<double>(clampedFreq);
    const double rho = static_cast<double>(clampedRes);
    const double g = std::tan(kPi * fc / static_cast<double>(sr));
    const double kres = compute_kres(fc, rho);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        double lp, bp, hp;
        FSWasp_step(static_cast<double>(in[i]), g, kres, s1, s2, lp, bp, hp);
        out[i] = static_cast<float>(hp);
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

// -------------------------------------------------------------
// Audio-rate frequency modulation (a-rate)
// -------------------------------------------------------------

void FSWasp_next_lp_a(FSWasp* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* freqIn = IN(1);
    float* out = OUT(0);
    const float sr = static_cast<float>(SAMPLERATE);
    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);
    const double rho = static_cast<double>(clampedRes);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
        const double fc = static_cast<double>(clampedFreq);
        const double g = std::tan(kPi * fc / static_cast<double>(sr));
        const double kres = compute_kres(fc, rho);

        double lp, bp, hp;
        FSWasp_step(static_cast<double>(in[i]), g, kres, s1, s2, lp, bp, hp);
        out[i] = static_cast<float>(lp);
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

void FSWasp_next_bp_a(FSWasp* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* freqIn = IN(1);
    float* out = OUT(0);
    const float sr = static_cast<float>(SAMPLERATE);
    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);
    const double rho = static_cast<double>(clampedRes);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
        const double fc = static_cast<double>(clampedFreq);
        const double g = std::tan(kPi * fc / static_cast<double>(sr));
        const double kres = compute_kres(fc, rho);

        double lp, bp, hp;
        FSWasp_step(static_cast<double>(in[i]), g, kres, s1, s2, lp, bp, hp);
        out[i] = static_cast<float>(bp);
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

void FSWasp_next_hp_a(FSWasp* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* freqIn = IN(1);
    float* out = OUT(0);
    const float sr = static_cast<float>(SAMPLERATE);
    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);
    const double rho = static_cast<double>(clampedRes);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
        const double fc = static_cast<double>(clampedFreq);
        const double g = std::tan(kPi * fc / static_cast<double>(sr));
        const double kres = compute_kres(fc, rho);

        double lp, bp, hp;
        FSWasp_step(static_cast<double>(in[i]), g, kres, s1, s2, lp, bp, hp);
        out[i] = static_cast<float>(hp);
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

// -------------------------------------------------------------
// Constructor
// -------------------------------------------------------------

void FSWasp_Ctor(FSWasp* unit) {
    unit->m_s1 = 0.0;
    unit->m_s2 = 0.0;
    unit->m_freq = -1.0f;
    unit->m_res = -1.0f;
    unit->m_drive = 1.0f;

    const int mode = static_cast<int>(IN0(4));
    unit->m_mode = (mode >= 0 && mode <= 2) ? mode : 0;

    const bool isAudioRateFreq = (INRATE(1) == calc_FullRate);

    switch (unit->m_mode) {
        case 1: // Band-Pass
            if (isAudioRateFreq) {
                SETCALC(FSWasp_next_bp_a);
                FSWasp_next_bp_a(unit, 1);
            } else {
                SETCALC(FSWasp_next_bp_k);
                FSWasp_next_bp_k(unit, 1);
            }
            break;

        case 2: // High-Pass
            if (isAudioRateFreq) {
                SETCALC(FSWasp_next_hp_a);
                FSWasp_next_hp_a(unit, 1);
            } else {
                SETCALC(FSWasp_next_hp_k);
                FSWasp_next_hp_k(unit, 1);
            }
            break;

        case 0: // Low-Pass (default)
        default:
            if (isAudioRateFreq) {
                SETCALC(FSWasp_next_lp_a);
                FSWasp_next_lp_a(unit, 1);
            } else {
                SETCALC(FSWasp_next_lp_k);
                FSWasp_next_lp_k(unit, 1);
            }
            break;
    }
}

} // namespace fs
