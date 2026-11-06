#include "MS20Circuit.hpp"
#include <cmath>
#include <algorithm>

namespace ms20 {

static constexpr double kPi = 3.141592653589793238462643383279502884;
static constexpr double kMaxResonanceK = 4.0;
static constexpr double kAlpha = 0.25; // Typical reverse-active alpha_R for Korg-35 BJT pair

// Reverse-saturation BJT variable resistance function (Stinchcombe Section 3.1)
static inline void phi_bjt(double v, double drive, double inv_drive, double& val, double& prime) {
    const double nu = drive * v;
    const double abs_nu = std::abs(nu);
    const double clipped_nu = (abs_nu < 40.0) ? abs_nu : 40.0;
    const double exp_neg = std::exp(-clipped_nu);

    if (nu >= 0.0) {
        const double den = kAlpha + (1.0 - kAlpha) * exp_neg;
        val = ((1.0 - exp_neg) / den) * inv_drive;
        prime = exp_neg / (den * den);
    } else {
        const double den = kAlpha * exp_neg + (1.0 - kAlpha);
        val = ((exp_neg - 1.0) / den) * inv_drive;
        prime = exp_neg / (den * den);
    }
}

// Forward-amplifier antiparallel diode limiter (Stinchcombe Section 5)
static inline void f_diode(double v, double drive, double inv_drive, double& val, double& prime) {
    const double arg = drive * v;
    const double arg2 = arg * arg;
    const double d = std::sqrt(1.0 + arg2);
    val = (arg / d) * inv_drive;
    prime = 1.0 / (d * (1.0 + arg2));
}

// Single-sample core solver for 2x2 MNA circuit model
static inline double MS20Circuit_step(double vin1, double vref, double& v1, double& v2,
                                      double& s1, double& s2, double g, double K,
                                      double drive, double inv_drive)
{
    const double s1_plus_s2 = s1 + s2;

    for (int iter = 0; iter < 3; ++iter) {
        const double u1 = vin1 - v1;
        const double u2 = v1 - v2;

        double phi1, dphi1, phi2, dphi2, fv2, dfv2;
        phi_bjt(u1, drive, inv_drive, phi1, dphi1);
        phi_bjt(u2, drive, inv_drive, phi2, dphi2);
        f_diode(v2, drive, inv_drive, fv2, dfv2);

        const double F1 = v1 + v2 - vref - K * fv2 - g * phi1 - s1_plus_s2;
        const double F2 = v2 - vref - g * phi2 - s2;

        const double j11 = 1.0 + g * dphi1;
        const double j12 = 1.0 - K * dfv2;
        const double j21 = -g * dphi2;
        const double j22 = 1.0 + g * dphi2;

        const double det = j11 * j22 - j12 * j21;
        const double inv_det = (std::abs(det) > 1e-12) ? (1.0 / det) : 1.0;

        const double dv1 = -(j22 * F1 - j12 * F2) * inv_det;
        const double dv2 = -(-j21 * F1 + j11 * F2) * inv_det;

        v1 += dv1;
        v2 += dv2;
    }

    double fv2_final, dfv2_dummy;
    f_diode(v2, drive, inv_drive, fv2_final, dfv2_dummy);

    const double vc2 = v2 - vref;
    const double vc1 = v1 - K * fv2_final;

    s1 = 2.0 * vc1 - s1;
    s2 = 2.0 * vc2 - s2;

    return fv2_final;
}

// -------------------------------------------------------------
// 1x Processing Functions
// -------------------------------------------------------------

void MS20Circuit_next_lp_k(MS20Circuit* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);
    const float sr = static_cast<float>(SAMPLERATE);
    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    const float clampedFreq = sc_clip(IN0(1), minCutoff, nyquistLimit);
    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);
    const float clampedDrive = sc_clip(IN0(3), 0.01f, 10.0f);

    const double K = static_cast<double>(clampedRes) * kMaxResonanceK;
    const double drive = static_cast<double>(clampedDrive);
    const double inv_drive = 1.0 / drive;
    const double g = std::tan(kPi * static_cast<double>(clampedFreq) / static_cast<double>(sr));

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;
    double v1 = unit->m_v1;
    double v2 = unit->m_v2;

    for (int i = 0; i < inNumSamples; ++i) {
        const double x = static_cast<double>(in[i]);
        out[i] = static_cast<float>(MS20Circuit_step(x, 0.0, v1, v2, s1, s2, g, K, drive, inv_drive));
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
    unit->m_v1 = zapgremlins(v1);
    unit->m_v2 = zapgremlins(v2);
}

void MS20Circuit_next_hp_k(MS20Circuit* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);
    const float sr = static_cast<float>(SAMPLERATE);
    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    const float clampedFreq = sc_clip(IN0(1), minCutoff, nyquistLimit);
    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);
    const float clampedDrive = sc_clip(IN0(3), 0.01f, 10.0f);

    const double K = static_cast<double>(clampedRes) * kMaxResonanceK;
    const double drive = static_cast<double>(clampedDrive);
    const double inv_drive = 1.0 / drive;
    const double g = std::tan(kPi * static_cast<double>(clampedFreq) / static_cast<double>(sr));

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;
    double v1 = unit->m_v1;
    double v2 = unit->m_v2;

    for (int i = 0; i < inNumSamples; ++i) {
        const double x = static_cast<double>(in[i]);
        out[i] = static_cast<float>(MS20Circuit_step(0.0, x, v1, v2, s1, s2, g, K, drive, inv_drive));
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
    unit->m_v1 = zapgremlins(v1);
    unit->m_v2 = zapgremlins(v2);
}

void MS20Circuit_next_lp_a(MS20Circuit* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* freqIn = IN(1);
    float* out = OUT(0);
    const float sr = static_cast<float>(SAMPLERATE);
    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);
    const float clampedDrive = sc_clip(IN0(3), 0.01f, 10.0f);

    const double K = static_cast<double>(clampedRes) * kMaxResonanceK;
    const double drive = static_cast<double>(clampedDrive);
    const double inv_drive = 1.0 / drive;

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;
    double v1 = unit->m_v1;
    double v2 = unit->m_v2;

    for (int i = 0; i < inNumSamples; ++i) {
        const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
        const double g = std::tan(kPi * static_cast<double>(clampedFreq) / static_cast<double>(sr));
        const double x = static_cast<double>(in[i]);
        out[i] = static_cast<float>(MS20Circuit_step(x, 0.0, v1, v2, s1, s2, g, K, drive, inv_drive));
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
    unit->m_v1 = zapgremlins(v1);
    unit->m_v2 = zapgremlins(v2);
}

void MS20Circuit_next_hp_a(MS20Circuit* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* freqIn = IN(1);
    float* out = OUT(0);
    const float sr = static_cast<float>(SAMPLERATE);
    const float nyquistLimit = 0.49f * sr;
    const float minCutoff = 10.0f;

    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);
    const float clampedDrive = sc_clip(IN0(3), 0.01f, 10.0f);

    const double K = static_cast<double>(clampedRes) * kMaxResonanceK;
    const double drive = static_cast<double>(clampedDrive);
    const double inv_drive = 1.0 / drive;

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;
    double v1 = unit->m_v1;
    double v2 = unit->m_v2;

    for (int i = 0; i < inNumSamples; ++i) {
        const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
        const double g = std::tan(kPi * static_cast<double>(clampedFreq) / static_cast<double>(sr));
        const double x = static_cast<double>(in[i]);
        out[i] = static_cast<float>(MS20Circuit_step(0.0, x, v1, v2, s1, s2, g, K, drive, inv_drive));
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
    unit->m_v1 = zapgremlins(v1);
    unit->m_v2 = zapgremlins(v2);
}

// -------------------------------------------------------------
// 2x Polyphase Oversampling Processing Functions
// -------------------------------------------------------------

void MS20Circuit_next_lp_k_2x(MS20Circuit* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);
    const double sr2x = 2.0 * static_cast<double>(SAMPLERATE);
    const float nyquistLimit = static_cast<float>(0.49 * sr2x);
    const float minCutoff = 10.0f;

    const float clampedFreq = sc_clip(IN0(1), minCutoff, nyquistLimit);
    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);
    const float clampedDrive = sc_clip(IN0(3), 0.01f, 10.0f);

    const double K = static_cast<double>(clampedRes) * kMaxResonanceK;
    const double drive = static_cast<double>(clampedDrive);
    const double inv_drive = 1.0 / drive;
    const double g = std::tan(kPi * static_cast<double>(clampedFreq) / sr2x);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;
    double v1 = unit->m_v1;
    double v2 = unit->m_v2;

    for (int i = 0; i < inNumSamples; ++i) {
        double v0_in, v1_in;
        unit->m_os.upsample(static_cast<double>(in[i]), v0_in, v1_in);
        const double y0 = MS20Circuit_step(v0_in, 0.0, v1, v2, s1, s2, g, K, drive, inv_drive);
        const double y1 = MS20Circuit_step(v1_in, 0.0, v1, v2, s1, s2, g, K, drive, inv_drive);
        out[i] = static_cast<float>(unit->m_os.decimate(y0, y1));
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
    unit->m_v1 = zapgremlins(v1);
    unit->m_v2 = zapgremlins(v2);
    unit->m_os.zap();
}

void MS20Circuit_next_hp_k_2x(MS20Circuit* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);
    const double sr2x = 2.0 * static_cast<double>(SAMPLERATE);
    const float nyquistLimit = static_cast<float>(0.49 * sr2x);
    const float minCutoff = 10.0f;

    const float clampedFreq = sc_clip(IN0(1), minCutoff, nyquistLimit);
    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);
    const float clampedDrive = sc_clip(IN0(3), 0.01f, 10.0f);

    const double K = static_cast<double>(clampedRes) * kMaxResonanceK;
    const double drive = static_cast<double>(clampedDrive);
    const double inv_drive = 1.0 / drive;
    const double g = std::tan(kPi * static_cast<double>(clampedFreq) / sr2x);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;
    double v1 = unit->m_v1;
    double v2 = unit->m_v2;

    for (int i = 0; i < inNumSamples; ++i) {
        double v0_in, v1_in;
        unit->m_os.upsample(static_cast<double>(in[i]), v0_in, v1_in);
        const double y0 = MS20Circuit_step(0.0, v0_in, v1, v2, s1, s2, g, K, drive, inv_drive);
        const double y1 = MS20Circuit_step(0.0, v1_in, v1, v2, s1, s2, g, K, drive, inv_drive);
        out[i] = static_cast<float>(unit->m_os.decimate(y0, y1));
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
    unit->m_v1 = zapgremlins(v1);
    unit->m_v2 = zapgremlins(v2);
    unit->m_os.zap();
}

void MS20Circuit_next_lp_a_2x(MS20Circuit* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* freqIn = IN(1);
    float* out = OUT(0);
    const double sr2x = 2.0 * static_cast<double>(SAMPLERATE);
    const float nyquistLimit = static_cast<float>(0.49 * sr2x);
    const float minCutoff = 10.0f;

    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);
    const float clampedDrive = sc_clip(IN0(3), 0.01f, 10.0f);

    const double K = static_cast<double>(clampedRes) * kMaxResonanceK;
    const double drive = static_cast<double>(clampedDrive);
    const double inv_drive = 1.0 / drive;

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;
    double v1 = unit->m_v1;
    double v2 = unit->m_v2;

    for (int i = 0; i < inNumSamples; ++i) {
        const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
        const double g = std::tan(kPi * static_cast<double>(clampedFreq) / sr2x);
        double v0_in, v1_in;
        unit->m_os.upsample(static_cast<double>(in[i]), v0_in, v1_in);
        const double y0 = MS20Circuit_step(v0_in, 0.0, v1, v2, s1, s2, g, K, drive, inv_drive);
        const double y1 = MS20Circuit_step(v1_in, 0.0, v1, v2, s1, s2, g, K, drive, inv_drive);
        out[i] = static_cast<float>(unit->m_os.decimate(y0, y1));
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
    unit->m_v1 = zapgremlins(v1);
    unit->m_v2 = zapgremlins(v2);
    unit->m_os.zap();
}

void MS20Circuit_next_hp_a_2x(MS20Circuit* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* freqIn = IN(1);
    float* out = OUT(0);
    const double sr2x = 2.0 * static_cast<double>(SAMPLERATE);
    const float nyquistLimit = static_cast<float>(0.49 * sr2x);
    const float minCutoff = 10.0f;

    const float clampedRes = sc_clip(IN0(2), 0.0f, 1.0f);
    const float clampedDrive = sc_clip(IN0(3), 0.01f, 10.0f);

    const double K = static_cast<double>(clampedRes) * kMaxResonanceK;
    const double drive = static_cast<double>(clampedDrive);
    const double inv_drive = 1.0 / drive;

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;
    double v1 = unit->m_v1;
    double v2 = unit->m_v2;

    for (int i = 0; i < inNumSamples; ++i) {
        const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
        const double g = std::tan(kPi * static_cast<double>(clampedFreq) / sr2x);
        double v0_in, v1_in;
        unit->m_os.upsample(static_cast<double>(in[i]), v0_in, v1_in);
        const double y0 = MS20Circuit_step(0.0, v0_in, v1, v2, s1, s2, g, K, drive, inv_drive);
        const double y1 = MS20Circuit_step(0.0, v1_in, v1, v2, s1, s2, g, K, drive, inv_drive);
        out[i] = static_cast<float>(unit->m_os.decimate(y0, y1));
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
    unit->m_v1 = zapgremlins(v1);
    unit->m_v2 = zapgremlins(v2);
    unit->m_os.zap();
}

// -------------------------------------------------------------
// Constructor
// -------------------------------------------------------------

void MS20Circuit_Ctor(MS20Circuit* unit) {
    unit->m_s1 = 0.0;
    unit->m_s2 = 0.0;
    unit->m_v1 = 0.0;
    unit->m_v2 = 0.0;
    unit->m_freq = -1.0f;
    unit->m_res = -1.0f;
    unit->m_drive = -1.0f;
    unit->m_os.reset();

    const int mode = static_cast<int>(IN0(4));
    unit->m_mode = (mode != 0) ? 1 : 0;

    const bool oversample2x = (unit->mNumInputs > 5) && (IN0(5) >= 1.0f);
    unit->m_oversample = oversample2x ? 1 : 0;

    const bool isAudioRateFreq = (INRATE(1) == calc_FullRate);

    if (unit->m_mode == 1) { // HP
        if (oversample2x) {
            if (isAudioRateFreq) {
                SETCALC(MS20Circuit_next_hp_a_2x);
                MS20Circuit_next_hp_a_2x(unit, 1);
            } else {
                SETCALC(MS20Circuit_next_hp_k_2x);
                MS20Circuit_next_hp_k_2x(unit, 1);
            }
        } else {
            if (isAudioRateFreq) {
                SETCALC(MS20Circuit_next_hp_a);
                MS20Circuit_next_hp_a(unit, 1);
            } else {
                SETCALC(MS20Circuit_next_hp_k);
                MS20Circuit_next_hp_k(unit, 1);
            }
        }
    } else { // LP
        if (oversample2x) {
            if (isAudioRateFreq) {
                SETCALC(MS20Circuit_next_lp_a_2x);
                MS20Circuit_next_lp_a_2x(unit, 1);
            } else {
                SETCALC(MS20Circuit_next_lp_k_2x);
                MS20Circuit_next_lp_k_2x(unit, 1);
            }
        } else {
            if (isAudioRateFreq) {
                SETCALC(MS20Circuit_next_lp_a);
                MS20Circuit_next_lp_a(unit, 1);
            } else {
                SETCALC(MS20Circuit_next_lp_k);
                MS20Circuit_next_lp_k(unit, 1);
            }
        }
    }
}

} // namespace ms20
