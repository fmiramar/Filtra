#include "CS80.hpp"
#include <cmath>
#include <algorithm>

namespace fs {

static constexpr double kPi = 3.14159265358979323846;

static inline double clamp_d(double val, double minVal, double maxVal) {
    return std::max(minVal, std::min(maxVal, val));
}

void CS80_Ctor(CS80* unit) {
    unit->m_hp_s1 = 0.0;
    unit->m_hp_s2 = 0.0;
    unit->m_lp_s1 = 0.0;
    unit->m_lp_s2 = 0.0;

    bool hpAudio = (INRATE(1) == calc_FullRate);
    bool lpAudio = (INRATE(3) == calc_FullRate);

    if (hpAudio && lpAudio) {
        SETCALC(CS80_next_aa);
    } else if (hpAudio && !lpAudio) {
        SETCALC(CS80_next_ak);
    } else if (!hpAudio && lpAudio) {
        SETCALC(CS80_next_ka);
    } else {
        SETCALC(CS80_next_kk);
    }

    OUT0(0) = 0.0f;
}

// Control-rate HP and LP frequencies
void CS80_next_kk(CS80* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);

    const double sampleRate = SAMPLERATE;
    const double nyquistLimit = sampleRate * 0.49;

    const double hpFreq = clamp_d(IN0(1), 10.0, nyquistLimit);
    const double hpRes  = clamp_d(IN0(2), 0.0, 1.0);
    const double lpFreq = clamp_d(IN0(3), 10.0, nyquistLimit);
    const double lpRes  = clamp_d(IN0(4), 0.0, 1.0);
    const double drive  = clamp_d(IN0(5), 0.01, 20.0);
    const double invDrive = 1.0 / drive;

    // HP stage coefficients
    const double g_hp = std::tan(kPi * hpFreq / sampleRate);
    const double R_hp = 2.0 * (1.0 - 0.999 * hpRes);
    const double denom_hp = 1.0 / (1.0 + R_hp * g_hp + g_hp * g_hp);

    // LP stage coefficients
    const double g_lp = std::tan(kPi * lpFreq / sampleRate);
    const double R_lp = 2.0 * (1.0 - 0.999 * lpRes);
    const double denom_lp = 1.0 / (1.0 + R_lp * g_lp + g_lp * g_lp);

    double hp_s1 = unit->m_hp_s1;
    double hp_s2 = unit->m_hp_s2;
    double lp_s1 = unit->m_lp_s1;
    double lp_s2 = unit->m_lp_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        const double x = static_cast<double>(in[i]);

        // 1. High-Pass Stage (TPT SVF HP output)
        const double v_hp = (x - (R_hp + g_hp) * hp_s1 - hp_s2) * denom_hp;
        const double v_hp_bp = g_hp * v_hp + hp_s1;
        const double v_hp_lp = g_hp * v_hp_bp + hp_s2;
        hp_s1 = 2.0 * v_hp_bp - hp_s1;
        hp_s2 = 2.0 * v_hp_lp - hp_s2;
        hp_s1 = std::tanh(drive * hp_s1 * 0.5) * (2.0 * invDrive);
        hp_s2 = std::tanh(drive * hp_s2 * 0.5) * (2.0 * invDrive);

        // 2. Inter-stage non-linear drive
        const double mid = std::tanh(drive * v_hp);

        // 3. Low-Pass Stage (TPT SVF LP output)
        const double v_lp_hp = (mid - (R_lp + g_lp) * lp_s1 - lp_s2) * denom_lp;
        const double v_lp_bp = g_lp * v_lp_hp + lp_s1;
        const double v_lp = g_lp * v_lp_bp + lp_s2;
        lp_s1 = 2.0 * v_lp_bp - lp_s1;
        lp_s2 = 2.0 * v_lp - lp_s2;
        lp_s1 = std::tanh(drive * lp_s1 * 0.5) * (2.0 * invDrive);
        lp_s2 = std::tanh(drive * lp_s2 * 0.5) * (2.0 * invDrive);

        out[i] = static_cast<float>(v_lp);
    }

    unit->m_hp_s1 = hp_s1;
    unit->m_hp_s2 = hp_s2;
    unit->m_lp_s1 = lp_s1;
    unit->m_lp_s2 = lp_s2;
}

// Audio-rate HP frequency, Control-rate LP frequency
void CS80_next_ak(CS80* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* hpFreqIn = IN(1);
    float* out = OUT(0);

    const double sampleRate = SAMPLERATE;
    const double nyquistLimit = sampleRate * 0.49;

    const double hpRes  = clamp_d(IN0(2), 0.0, 1.0);
    const double lpFreq = clamp_d(IN0(3), 10.0, nyquistLimit);
    const double lpRes  = clamp_d(IN0(4), 0.0, 1.0);
    const double drive  = clamp_d(IN0(5), 0.01, 20.0);
    const double invDrive = 1.0 / drive;

    const double R_hp = 2.0 * (1.0 - 0.999 * hpRes);

    const double g_lp = std::tan(kPi * lpFreq / sampleRate);
    const double R_lp = 2.0 * (1.0 - 0.999 * lpRes);
    const double denom_lp = 1.0 / (1.0 + R_lp * g_lp + g_lp * g_lp);

    double hp_s1 = unit->m_hp_s1;
    double hp_s2 = unit->m_hp_s2;
    double lp_s1 = unit->m_lp_s1;
    double lp_s2 = unit->m_lp_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        const double x = static_cast<double>(in[i]);

        const double hpFreq = clamp_d(hpFreqIn[i], 10.0, nyquistLimit);
        const double g_hp = std::tan(kPi * hpFreq / sampleRate);
        const double denom_hp = 1.0 / (1.0 + R_hp * g_hp + g_hp * g_hp);

        const double v_hp = (x - (R_hp + g_hp) * hp_s1 - hp_s2) * denom_hp;
        const double v_hp_bp = g_hp * v_hp + hp_s1;
        const double v_hp_lp = g_hp * v_hp_bp + hp_s2;
        hp_s1 = 2.0 * v_hp_bp - hp_s1;
        hp_s2 = 2.0 * v_hp_lp - hp_s2;
        hp_s1 = std::tanh(drive * hp_s1 * 0.5) * (2.0 * invDrive);
        hp_s2 = std::tanh(drive * hp_s2 * 0.5) * (2.0 * invDrive);

        const double mid = std::tanh(drive * v_hp);

        const double v_lp_hp = (mid - (R_lp + g_lp) * lp_s1 - lp_s2) * denom_lp;
        const double v_lp_bp = g_lp * v_lp_hp + lp_s1;
        const double v_lp = g_lp * v_lp_bp + lp_s2;
        lp_s1 = 2.0 * v_lp_bp - lp_s1;
        lp_s2 = 2.0 * v_lp - lp_s2;
        lp_s1 = std::tanh(drive * lp_s1 * 0.5) * (2.0 * invDrive);
        lp_s2 = std::tanh(drive * lp_s2 * 0.5) * (2.0 * invDrive);

        out[i] = static_cast<float>(v_lp);
    }

    unit->m_hp_s1 = hp_s1;
    unit->m_hp_s2 = hp_s2;
    unit->m_lp_s1 = lp_s1;
    unit->m_lp_s2 = lp_s2;
}

// Control-rate HP frequency, Audio-rate LP frequency
void CS80_next_ka(CS80* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* lpFreqIn = IN(3);
    float* out = OUT(0);

    const double sampleRate = SAMPLERATE;
    const double nyquistLimit = sampleRate * 0.49;

    const double hpFreq = clamp_d(IN0(1), 10.0, nyquistLimit);
    const double hpRes  = clamp_d(IN0(2), 0.0, 1.0);
    const double lpRes  = clamp_d(IN0(4), 0.0, 1.0);
    const double drive  = clamp_d(IN0(5), 0.01, 20.0);
    const double invDrive = 1.0 / drive;

    const double g_hp = std::tan(kPi * hpFreq / sampleRate);
    const double R_hp = 2.0 * (1.0 - 0.999 * hpRes);
    const double denom_hp = 1.0 / (1.0 + R_hp * g_hp + g_hp * g_hp);

    const double R_lp = 2.0 * (1.0 - 0.999 * lpRes);

    double hp_s1 = unit->m_hp_s1;
    double hp_s2 = unit->m_hp_s2;
    double lp_s1 = unit->m_lp_s1;
    double lp_s2 = unit->m_lp_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        const double x = static_cast<double>(in[i]);

        const double v_hp = (x - (R_hp + g_hp) * hp_s1 - hp_s2) * denom_hp;
        const double v_hp_bp = g_hp * v_hp + hp_s1;
        const double v_hp_lp = g_hp * v_hp_bp + hp_s2;
        hp_s1 = 2.0 * v_hp_bp - hp_s1;
        hp_s2 = 2.0 * v_hp_lp - hp_s2;
        hp_s1 = std::tanh(drive * hp_s1 * 0.5) * (2.0 * invDrive);
        hp_s2 = std::tanh(drive * hp_s2 * 0.5) * (2.0 * invDrive);

        const double mid = std::tanh(drive * v_hp);

        const double lpFreq = clamp_d(lpFreqIn[i], 10.0, nyquistLimit);
        const double g_lp = std::tan(kPi * lpFreq / sampleRate);
        const double denom_lp = 1.0 / (1.0 + R_lp * g_lp + g_lp * g_lp);

        const double v_lp_hp = (mid - (R_lp + g_lp) * lp_s1 - lp_s2) * denom_lp;
        const double v_lp_bp = g_lp * v_lp_hp + lp_s1;
        const double v_lp = g_lp * v_lp_bp + lp_s2;
        lp_s1 = 2.0 * v_lp_bp - lp_s1;
        lp_s2 = 2.0 * v_lp - lp_s2;
        lp_s1 = std::tanh(drive * lp_s1 * 0.5) * (2.0 * invDrive);
        lp_s2 = std::tanh(drive * lp_s2 * 0.5) * (2.0 * invDrive);

        out[i] = static_cast<float>(v_lp);
    }

    unit->m_hp_s1 = hp_s1;
    unit->m_hp_s2 = hp_s2;
    unit->m_lp_s1 = lp_s1;
    unit->m_lp_s2 = lp_s2;
}

// Audio-rate HP and LP frequencies
void CS80_next_aa(CS80* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* hpFreqIn = IN(1);
    const float* lpFreqIn = IN(3);
    float* out = OUT(0);

    const double sampleRate = SAMPLERATE;
    const double nyquistLimit = sampleRate * 0.49;

    const double hpRes  = clamp_d(IN0(2), 0.0, 1.0);
    const double lpRes  = clamp_d(IN0(4), 0.0, 1.0);
    const double drive  = clamp_d(IN0(5), 0.01, 20.0);
    const double invDrive = 1.0 / drive;

    const double R_hp = 2.0 * (1.0 - 0.999 * hpRes);
    const double R_lp = 2.0 * (1.0 - 0.999 * lpRes);

    double hp_s1 = unit->m_hp_s1;
    double hp_s2 = unit->m_hp_s2;
    double lp_s1 = unit->m_lp_s1;
    double lp_s2 = unit->m_lp_s2;

    for (int i = 0; i < inNumSamples; ++i) {
        const double x = static_cast<double>(in[i]);

        const double hpFreq = clamp_d(hpFreqIn[i], 10.0, nyquistLimit);
        const double g_hp = std::tan(kPi * hpFreq / sampleRate);
        const double denom_hp = 1.0 / (1.0 + R_hp * g_hp + g_hp * g_hp);

        const double v_hp = (x - (R_hp + g_hp) * hp_s1 - hp_s2) * denom_hp;
        const double v_hp_bp = g_hp * v_hp + hp_s1;
        const double v_hp_lp = g_hp * v_hp_bp + hp_s2;
        hp_s1 = 2.0 * v_hp_bp - hp_s1;
        hp_s2 = 2.0 * v_hp_lp - hp_s2;
        hp_s1 = std::tanh(drive * hp_s1 * 0.5) * (2.0 * invDrive);
        hp_s2 = std::tanh(drive * hp_s2 * 0.5) * (2.0 * invDrive);

        const double mid = std::tanh(drive * v_hp);

        const double lpFreq = clamp_d(lpFreqIn[i], 10.0, nyquistLimit);
        const double g_lp = std::tan(kPi * lpFreq / sampleRate);
        const double denom_lp = 1.0 / (1.0 + R_lp * g_lp + g_lp * g_lp);

        const double v_lp_hp = (mid - (R_lp + g_lp) * lp_s1 - lp_s2) * denom_lp;
        const double v_lp_bp = g_lp * v_lp_hp + lp_s1;
        const double v_lp = g_lp * v_lp_bp + lp_s2;
        lp_s1 = 2.0 * v_lp_bp - lp_s1;
        lp_s2 = 2.0 * v_lp - lp_s2;
        lp_s1 = std::tanh(drive * lp_s1 * 0.5) * (2.0 * invDrive);
        lp_s2 = std::tanh(drive * lp_s2 * 0.5) * (2.0 * invDrive);

        out[i] = static_cast<float>(v_lp);
    }

    unit->m_hp_s1 = hp_s1;
    unit->m_hp_s2 = hp_s2;
    unit->m_lp_s1 = lp_s1;
    unit->m_lp_s2 = lp_s2;
}

} // namespace fs
