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

// -------------------------------------------------------------
// Linear small-signal state-variable step (Stage W1)
// -------------------------------------------------------------
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
// Circuit-informed nonlinear state-variable step (Stage W2)
// Reference: Köper, Holters, Esqueda, Parker (DAFx 2022), Section 4
// Models CA3080 differential OTA transconductance saturation (tanh)
// and CD4069 unbuffered CMOS inverter soft saturation inside the loops.
// -------------------------------------------------------------
static inline void FSWasp_step_nl(double in_sample, double g, double kres, double drive,
                                  double& s1, double& s2,
                                  double& out_lp, double& out_bp, double& out_hp)
{
    const double alpha = drive;
    const double inv_alpha = 1.0 / alpha;
    const double beta = 0.5 * drive;
    const double beta2 = beta * beta;

    // Initial guess from linear TPT solution
    const double inv_den = 1.0 / (1.0 + kres * g + g * g);
    double v_hp = -(in_sample + (kres + g) * s1 + s2) * inv_den;

    double w1 = 0.0;
    double w2 = 0.0;
    double v_bp = 0.0;
    double v_lp = 0.0;

    // Capped 1-D Newton-Raphson implicit loop (max 4 iterations, tolerance 1e-6)
    constexpr int kMaxIter = 4;
    constexpr double kTol = 1.0e-6;

    for (int it = 0; it < kMaxIter; ++it) {
        // Integrator 1: OTA CA3080 input tanh saturation + CMOS CD4069 inverter
        const double t_hp = std::tanh(alpha * v_hp);
        const double f_ota_hp = t_hp * inv_alpha;
        const double df_ota_hp = 1.0 - t_hp * t_hp;

        w1 = g * f_ota_hp + s1;
        const double b1_sq = 1.0 + beta2 * w1 * w1;
        const double inv_sqrt_b1 = 1.0 / std::sqrt(b1_sq);
        v_bp = w1 * inv_sqrt_b1;
        const double df_cmos_w1 = inv_sqrt_b1 / b1_sq;
        const double dv_bp = df_cmos_w1 * g * df_ota_hp;

        // Integrator 2: OTA CA3080 input tanh saturation + CMOS CD4069 inverter
        const double t_bp = std::tanh(alpha * v_bp);
        const double f_ota_bp = t_bp * inv_alpha;
        const double df_ota_bp = 1.0 - t_bp * t_bp;

        w2 = g * f_ota_bp + s2;
        const double b2_sq = 1.0 + beta2 * w2 * w2;
        const double inv_sqrt_b2 = 1.0 / std::sqrt(b2_sq);
        v_lp = w2 * inv_sqrt_b2;
        const double df_cmos_w2 = inv_sqrt_b2 / b2_sq;
        const double dv_lp = df_cmos_w2 * g * df_ota_bp * dv_bp;

        // Resonance feedback limiter path (diodes/CMOS)
        const double t_res = std::tanh(alpha * v_bp);
        const double f_d_bp = t_res * inv_alpha;
        const double df_d_bp = 1.0 - t_res * t_res;

        // Summing node (inverting CMOS amplifier IC1)
        const double u = in_sample + kres * f_d_bp + v_lp;
        const double bu_sq = 1.0 + beta2 * u * u;
        const double inv_sqrt_bu = 1.0 / std::sqrt(bu_sq);
        const double f_cmos_u = u * inv_sqrt_bu;
        const double df_cmos_u = inv_sqrt_bu / bu_sq;

        const double du = kres * df_d_bp * dv_bp + dv_lp;

        // Residual F(v_hp) = v_hp + f_cmos(u)
        const double F = v_hp + f_cmos_u;
        const double dF = 1.0 + df_cmos_u * du;

        const double step = F / dF;
        v_hp -= step;

        if (std::abs(step) < kTol) {
            break;
        }
    }

    // Final evaluation with converged v_hp to ensure exact consistency
    const double t_hp_final = std::tanh(alpha * v_hp);
    w1 = g * (t_hp_final * inv_alpha) + s1;
    v_bp = w1 / std::sqrt(1.0 + beta2 * w1 * w1);

    const double t_bp_final = std::tanh(alpha * v_bp);
    w2 = g * (t_bp_final * inv_alpha) + s2;
    v_lp = w2 / std::sqrt(1.0 + beta2 * w2 * w2);

    // Trapezoidal state updates on capacitor charges
    s1 = 2.0 * w1 - s1;
    s2 = 2.0 * w2 - s2;

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
    const float clampedDrive = sc_clip(IN0(3), 0.0f, 20.0f);

    const double fc = static_cast<double>(clampedFreq);
    const double rho = static_cast<double>(clampedRes);
    const double drive = static_cast<double>(clampedDrive);
    const double g = std::tan(kPi * fc / static_cast<double>(sr));
    const double kres = compute_kres(fc, rho);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    if (drive <= 0.01) {
        for (int i = 0; i < inNumSamples; ++i) {
            double lp, bp, hp;
            FSWasp_step(static_cast<double>(in[i]), g, kres, s1, s2, lp, bp, hp);
            out[i] = static_cast<float>(lp);
        }
    } else {
        for (int i = 0; i < inNumSamples; ++i) {
            double lp, bp, hp;
            FSWasp_step_nl(static_cast<double>(in[i]), g, kres, drive, s1, s2, lp, bp, hp);
            out[i] = static_cast<float>(lp);
        }
    }

    s1 = std::clamp(s1, -100.0, 100.0);
    s2 = std::clamp(s2, -100.0, 100.0);
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
    const float clampedDrive = sc_clip(IN0(3), 0.0f, 20.0f);

    const double fc = static_cast<double>(clampedFreq);
    const double rho = static_cast<double>(clampedRes);
    const double drive = static_cast<double>(clampedDrive);
    const double g = std::tan(kPi * fc / static_cast<double>(sr));
    const double kres = compute_kres(fc, rho);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    if (drive <= 0.01) {
        for (int i = 0; i < inNumSamples; ++i) {
            double lp, bp, hp;
            FSWasp_step(static_cast<double>(in[i]), g, kres, s1, s2, lp, bp, hp);
            out[i] = static_cast<float>(bp);
        }
    } else {
        for (int i = 0; i < inNumSamples; ++i) {
            double lp, bp, hp;
            FSWasp_step_nl(static_cast<double>(in[i]), g, kres, drive, s1, s2, lp, bp, hp);
            out[i] = static_cast<float>(bp);
        }
    }

    s1 = std::clamp(s1, -100.0, 100.0);
    s2 = std::clamp(s2, -100.0, 100.0);
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
    const float clampedDrive = sc_clip(IN0(3), 0.0f, 20.0f);

    const double fc = static_cast<double>(clampedFreq);
    const double rho = static_cast<double>(clampedRes);
    const double drive = static_cast<double>(clampedDrive);
    const double g = std::tan(kPi * fc / static_cast<double>(sr));
    const double kres = compute_kres(fc, rho);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    if (drive <= 0.01) {
        for (int i = 0; i < inNumSamples; ++i) {
            double lp, bp, hp;
            FSWasp_step(static_cast<double>(in[i]), g, kres, s1, s2, lp, bp, hp);
            out[i] = static_cast<float>(hp);
        }
    } else {
        for (int i = 0; i < inNumSamples; ++i) {
            double lp, bp, hp;
            FSWasp_step_nl(static_cast<double>(in[i]), g, kres, drive, s1, s2, lp, bp, hp);
            out[i] = static_cast<float>(hp);
        }
    }

    s1 = std::clamp(s1, -100.0, 100.0);
    s2 = std::clamp(s2, -100.0, 100.0);
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
    const float clampedDrive = sc_clip(IN0(3), 0.0f, 20.0f);
    const double rho = static_cast<double>(clampedRes);
    const double drive = static_cast<double>(clampedDrive);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    if (drive <= 0.01) {
        for (int i = 0; i < inNumSamples; ++i) {
            const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
            const double fc = static_cast<double>(clampedFreq);
            const double g = std::tan(kPi * fc / static_cast<double>(sr));
            const double kres = compute_kres(fc, rho);

            double lp, bp, hp;
            FSWasp_step(static_cast<double>(in[i]), g, kres, s1, s2, lp, bp, hp);
            out[i] = static_cast<float>(lp);
        }
    } else {
        for (int i = 0; i < inNumSamples; ++i) {
            const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
            const double fc = static_cast<double>(clampedFreq);
            const double g = std::tan(kPi * fc / static_cast<double>(sr));
            const double kres = compute_kres(fc, rho);

            double lp, bp, hp;
            FSWasp_step_nl(static_cast<double>(in[i]), g, kres, drive, s1, s2, lp, bp, hp);
            out[i] = static_cast<float>(lp);
        }
    }

    s1 = std::clamp(s1, -100.0, 100.0);
    s2 = std::clamp(s2, -100.0, 100.0);
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
    const float clampedDrive = sc_clip(IN0(3), 0.0f, 20.0f);
    const double rho = static_cast<double>(clampedRes);
    const double drive = static_cast<double>(clampedDrive);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    if (drive <= 0.01) {
        for (int i = 0; i < inNumSamples; ++i) {
            const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
            const double fc = static_cast<double>(clampedFreq);
            const double g = std::tan(kPi * fc / static_cast<double>(sr));
            const double kres = compute_kres(fc, rho);

            double lp, bp, hp;
            FSWasp_step(static_cast<double>(in[i]), g, kres, s1, s2, lp, bp, hp);
            out[i] = static_cast<float>(bp);
        }
    } else {
        for (int i = 0; i < inNumSamples; ++i) {
            const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
            const double fc = static_cast<double>(clampedFreq);
            const double g = std::tan(kPi * fc / static_cast<double>(sr));
            const double kres = compute_kres(fc, rho);

            double lp, bp, hp;
            FSWasp_step_nl(static_cast<double>(in[i]), g, kres, drive, s1, s2, lp, bp, hp);
            out[i] = static_cast<float>(bp);
        }
    }

    s1 = std::clamp(s1, -100.0, 100.0);
    s2 = std::clamp(s2, -100.0, 100.0);
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
    const float clampedDrive = sc_clip(IN0(3), 0.0f, 20.0f);
    const double rho = static_cast<double>(clampedRes);
    const double drive = static_cast<double>(clampedDrive);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    if (drive <= 0.01) {
        for (int i = 0; i < inNumSamples; ++i) {
            const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
            const double fc = static_cast<double>(clampedFreq);
            const double g = std::tan(kPi * fc / static_cast<double>(sr));
            const double kres = compute_kres(fc, rho);

            double lp, bp, hp;
            FSWasp_step(static_cast<double>(in[i]), g, kres, s1, s2, lp, bp, hp);
            out[i] = static_cast<float>(hp);
        }
    } else {
        for (int i = 0; i < inNumSamples; ++i) {
            const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
            const double fc = static_cast<double>(clampedFreq);
            const double g = std::tan(kPi * fc / static_cast<double>(sr));
            const double kres = compute_kres(fc, rho);

            double lp, bp, hp;
            FSWasp_step_nl(static_cast<double>(in[i]), g, kres, drive, s1, s2, lp, bp, hp);
            out[i] = static_cast<float>(hp);
        }
    }

    s1 = std::clamp(s1, -100.0, 100.0);
    s2 = std::clamp(s2, -100.0, 100.0);
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
