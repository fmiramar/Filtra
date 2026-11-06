#include "MS20Diode.hpp"
#include <cmath>
#include <algorithm>

namespace ms20 {

static constexpr double kPi = 3.141592653589793238462643383279502884;
// Maximum feedback gain for nonlinear self-oscillation
static constexpr double kMaxResonanceK = 4.0;

// Single-sample core solver for Low-Pass mode
static inline double MS20Diode_step_lp(double x, double& s1, double& s2, double g, double K,
                                       double drive, double inv_drive, double c_lin,
                                       double inv_lin_den, double inv_1p2g)
{
    const double p = (1.0 + 2.0 * g) * s2 - g * s1 + g * g * x;
    double v = p * inv_lin_den;
    for (int iter = 0; iter < 3; ++iter) {
        const double arg = drive * v;
        const double arg2 = arg * arg;
        const double d = std::sqrt(1.0 + arg2);
        const double f_val = (arg / d) * inv_drive;
        const double f_prime = 1.0 / (d * (1.0 + arg2));
        const double F = c_lin * v - g * K * f_val - p;
        const double dF = c_lin - g * K * f_prime;
        v -= F / dF;
    }
    const double arg = drive * v;
    const double d = std::sqrt(1.0 + arg * arg);
    const double f_val = (arg / d) * inv_drive;
    const double vc2 = v;
    const double vc1 = (2.0 * g * K * f_val - g * vc2 - g * x + s1) * inv_1p2g;
    s1 = 2.0 * vc1 - s1;
    s2 = 2.0 * vc2 - s2;
    return f_val;
}

// Single-sample core solver for High-Pass mode
static inline double MS20Diode_step_hp(double x, double& s1, double& s2, double g, double K,
                                       double drive, double inv_drive, double c_lin,
                                       double inv_lin_den, double inv_1p2g)
{
    const double p_u = (1.0 + 2.0 * g) * (s2 + x) - g * s1;
    double u = p_u * inv_lin_den;
    for (int iter = 0; iter < 3; ++iter) {
        const double arg = drive * u;
        const double arg2 = arg * arg;
        const double d = std::sqrt(1.0 + arg2);
        const double f_val = (arg / d) * inv_drive;
        const double f_prime = 1.0 / (d * (1.0 + arg2));
        const double F = c_lin * u - g * K * f_val - p_u;
        const double dF = c_lin - g * K * f_prime;
        u -= F / dF;
    }
    const double arg = drive * u;
    const double d = std::sqrt(1.0 + arg * arg);
    const double f_val = (arg / d) * inv_drive;
    const double vc2 = u - x;
    const double vc1 = (2.0 * g * K * f_val - g * u + s1) * inv_1p2g;
    s1 = 2.0 * vc1 - s1;
    s2 = 2.0 * vc2 - s2;
    return f_val;
}

// -------------------------------------------------------------
// 1x Processing Functions
// -------------------------------------------------------------

void MS20Diode_next_lp(MS20Diode* unit, int inNumSamples) {
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
    const double c_lin = 1.0 + 3.0 * g + g * g;
    const double dK_lin = (K < 2.9) ? K : 2.9;
    const double inv_lin_den = 1.0 / (g * g + (3.0 - dK_lin) * g + 1.0);
    const double inv_1p2g = 1.0 / (1.0 + 2.0 * g);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        out[i] = static_cast<float>(MS20Diode_step_lp(static_cast<double>(in[i]), s1, s2, g, K, drive, inv_drive, c_lin, inv_lin_den, inv_1p2g));
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

void MS20Diode_next_hp(MS20Diode* unit, int inNumSamples) {
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
    const double c_lin = 1.0 + 3.0 * g + g * g;
    const double dK_lin = (K < 2.9) ? K : 2.9;
    const double inv_lin_den = 1.0 / (g * g + (3.0 - dK_lin) * g + 1.0);
    const double inv_1p2g = 1.0 / (1.0 + 2.0 * g);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        out[i] = static_cast<float>(MS20Diode_step_hp(static_cast<double>(in[i]), s1, s2, g, K, drive, inv_drive, c_lin, inv_lin_den, inv_1p2g));
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

void MS20Diode_next_lp_a(MS20Diode* unit, int inNumSamples) {
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
    const double dK_lin = (K < 2.9) ? K : 2.9;

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
        const double g = std::tan(kPi * static_cast<double>(clampedFreq) / static_cast<double>(sr));
        const double c_lin = 1.0 + 3.0 * g + g * g;
        const double inv_lin_den = 1.0 / (g * g + (3.0 - dK_lin) * g + 1.0);
        const double inv_1p2g = 1.0 / (1.0 + 2.0 * g);

        out[i] = static_cast<float>(MS20Diode_step_lp(static_cast<double>(in[i]), s1, s2, g, K, drive, inv_drive, c_lin, inv_lin_den, inv_1p2g));
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

void MS20Diode_next_hp_a(MS20Diode* unit, int inNumSamples) {
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
    const double dK_lin = (K < 2.9) ? K : 2.9;

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
        const double g = std::tan(kPi * static_cast<double>(clampedFreq) / static_cast<double>(sr));
        const double c_lin = 1.0 + 3.0 * g + g * g;
        const double inv_lin_den = 1.0 / (g * g + (3.0 - dK_lin) * g + 1.0);
        const double inv_1p2g = 1.0 / (1.0 + 2.0 * g);

        out[i] = static_cast<float>(MS20Diode_step_hp(static_cast<double>(in[i]), s1, s2, g, K, drive, inv_drive, c_lin, inv_lin_den, inv_1p2g));
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
}

// -------------------------------------------------------------
// 2x Polyphase Oversampling Processing Functions
// -------------------------------------------------------------

void MS20Diode_next_lp_2x(MS20Diode* unit, int inNumSamples) {
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
    const double c_lin = 1.0 + 3.0 * g + g * g;
    const double dK_lin = (K < 2.9) ? K : 2.9;
    const double inv_lin_den = 1.0 / (g * g + (3.0 - dK_lin) * g + 1.0);
    const double inv_1p2g = 1.0 / (1.0 + 2.0 * g);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        double v0, v1;
        unit->m_os.upsample(static_cast<double>(in[i]), v0, v1);
        const double y0 = MS20Diode_step_lp(v0, s1, s2, g, K, drive, inv_drive, c_lin, inv_lin_den, inv_1p2g);
        const double y1 = MS20Diode_step_lp(v1, s1, s2, g, K, drive, inv_drive, c_lin, inv_lin_den, inv_1p2g);
        out[i] = static_cast<float>(unit->m_os.decimate(y0, y1));
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
    unit->m_os.zap();
}

void MS20Diode_next_hp_2x(MS20Diode* unit, int inNumSamples) {
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
    const double c_lin = 1.0 + 3.0 * g + g * g;
    const double dK_lin = (K < 2.9) ? K : 2.9;
    const double inv_lin_den = 1.0 / (g * g + (3.0 - dK_lin) * g + 1.0);
    const double inv_1p2g = 1.0 / (1.0 + 2.0 * g);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        double v0, v1;
        unit->m_os.upsample(static_cast<double>(in[i]), v0, v1);
        const double y0 = MS20Diode_step_hp(v0, s1, s2, g, K, drive, inv_drive, c_lin, inv_lin_den, inv_1p2g);
        const double y1 = MS20Diode_step_hp(v1, s1, s2, g, K, drive, inv_drive, c_lin, inv_lin_den, inv_1p2g);
        out[i] = static_cast<float>(unit->m_os.decimate(y0, y1));
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
    unit->m_os.zap();
}

void MS20Diode_next_lp_a_2x(MS20Diode* unit, int inNumSamples) {
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
    const double dK_lin = (K < 2.9) ? K : 2.9;

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
        const double g = std::tan(kPi * static_cast<double>(clampedFreq) / sr2x);
        const double c_lin = 1.0 + 3.0 * g + g * g;
        const double inv_lin_den = 1.0 / (g * g + (3.0 - dK_lin) * g + 1.0);
        const double inv_1p2g = 1.0 / (1.0 + 2.0 * g);

        double v0, v1;
        unit->m_os.upsample(static_cast<double>(in[i]), v0, v1);
        const double y0 = MS20Diode_step_lp(v0, s1, s2, g, K, drive, inv_drive, c_lin, inv_lin_den, inv_1p2g);
        const double y1 = MS20Diode_step_lp(v1, s1, s2, g, K, drive, inv_drive, c_lin, inv_lin_den, inv_1p2g);
        out[i] = static_cast<float>(unit->m_os.decimate(y0, y1));
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
    unit->m_os.zap();
}

void MS20Diode_next_hp_a_2x(MS20Diode* unit, int inNumSamples) {
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
    const double dK_lin = (K < 2.9) ? K : 2.9;

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        const float clampedFreq = sc_clip(freqIn[i], minCutoff, nyquistLimit);
        const double g = std::tan(kPi * static_cast<double>(clampedFreq) / sr2x);
        const double c_lin = 1.0 + 3.0 * g + g * g;
        const double inv_lin_den = 1.0 / (g * g + (3.0 - dK_lin) * g + 1.0);
        const double inv_1p2g = 1.0 / (1.0 + 2.0 * g);

        double v0, v1;
        unit->m_os.upsample(static_cast<double>(in[i]), v0, v1);
        const double y0 = MS20Diode_step_hp(v0, s1, s2, g, K, drive, inv_drive, c_lin, inv_lin_den, inv_1p2g);
        const double y1 = MS20Diode_step_hp(v1, s1, s2, g, K, drive, inv_drive, c_lin, inv_lin_den, inv_1p2g);
        out[i] = static_cast<float>(unit->m_os.decimate(y0, y1));
    }

    unit->m_s1 = zapgremlins(s1);
    unit->m_s2 = zapgremlins(s2);
    unit->m_os.zap();
}

// -------------------------------------------------------------
// Constructor
// -------------------------------------------------------------

void MS20Diode_Ctor(MS20Diode* unit) {
    unit->m_s1 = 0.0;
    unit->m_s2 = 0.0;
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
                SETCALC(MS20Diode_next_hp_a_2x);
                MS20Diode_next_hp_a_2x(unit, 1);
            } else {
                SETCALC(MS20Diode_next_hp_2x);
                MS20Diode_next_hp_2x(unit, 1);
            }
        } else {
            if (isAudioRateFreq) {
                SETCALC(MS20Diode_next_hp_a);
                MS20Diode_next_hp_a(unit, 1);
            } else {
                SETCALC(MS20Diode_next_hp);
                MS20Diode_next_hp(unit, 1);
            }
        }
    } else { // LP
        if (oversample2x) {
            if (isAudioRateFreq) {
                SETCALC(MS20Diode_next_lp_a_2x);
                MS20Diode_next_lp_a_2x(unit, 1);
            } else {
                SETCALC(MS20Diode_next_lp_2x);
                MS20Diode_next_lp_2x(unit, 1);
            }
        } else {
            if (isAudioRateFreq) {
                SETCALC(MS20Diode_next_lp_a);
                MS20Diode_next_lp_a(unit, 1);
            } else {
                SETCALC(MS20Diode_next_lp);
                MS20Diode_next_lp(unit, 1);
            }
        }
    }
}

} // namespace ms20
