#include "VCFQ.hpp"
#include <cmath>
#include <algorithm>

namespace fs {

static constexpr double kPi = 3.14159265358979323846;

static inline double clamp_d(double val, double minVal, double maxVal) {
    return std::max(minVal, std::min(maxVal, val));
}

void VCFQ_Ctor(VCFQ* unit) {
    unit->m_s1 = 0.0;
    unit->m_s2 = 0.0;
    unit->m_prevTrig = 0.0f;
    unit->m_mode = std::max(0, std::min(3, static_cast<int>(IN0(5))));

    bool isAudioRate = (INRATE(2) == calc_FullRate);
    if (isAudioRate) {
        SETCALC(VCFQ_next_a);
    } else {
        SETCALC(VCFQ_next_k);
    }

    OUT0(0) = 0.0f;
}

// Control-rate frequency
void VCFQ_next_k(VCFQ* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* trigIn = IN(1);
    float* out = OUT(0);

    const double sampleRate = SAMPLERATE;
    const double nyquistLimit = sampleRate * 0.49;

    const double freq  = clamp_d(IN0(2), 10.0, nyquistLimit);
    const double q     = clamp_d(IN0(3), 0.5, 50.0);
    const double drive = clamp_d(IN0(4), 0.1, 20.0);
    const double invDrive = 1.0 / drive;
    const int mode     = unit->m_mode;

    const double g = std::tan(kPi * freq / sampleRate);
    const double R = 1.0 / q;
    const double denom = 1.0 / (1.0 + R * g + g * g);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;
    float prevTrig = unit->m_prevTrig;

    const bool trigAudio = (INRATE(1) == calc_FullRate);

    for (int i = 0; i < inNumSamples; ++i) {
        double x = static_cast<double>(in[i]);

        // Check trigger edge (transition from <= 0 to > 0)
        float curTrig = trigAudio ? trigIn[i] : trigIn[0];
        if (curTrig > 0.0f && prevTrig <= 0.0f) {
            // Serge ping excitation: inject impulse of magnitude proportional to trigger height
            s1 += static_cast<double>(curTrig) * 1.0;
        }
        prevTrig = curTrig;

        // 2-pole TPT State-Variable Filter step
        const double v_hp = (x - (R + g) * s1 - s2) * denom;
        const double v_bp = g * v_hp + s1;
        const double v_lp = g * v_bp + s2;

        // Trapezoidal state updates with AGC diode limiting
        s1 = 2.0 * v_bp - s1;
        s2 = 2.0 * v_lp - s2;

        s1 = std::tanh(drive * s1 * 0.5) * (2.0 * invDrive);
        s2 = std::tanh(drive * s2 * 0.5) * (2.0 * invDrive);

        double y = 0.0;
        switch (mode) {
            case 0: y = v_lp; break;
            case 1: y = v_bp; break;
            case 2: y = v_hp; break;
            case 3: y = v_hp + v_lp; break; // Notch
        }

        out[i] = static_cast<float>(y);
    }

    unit->m_s1 = s1;
    unit->m_s2 = s2;
    unit->m_prevTrig = prevTrig;
}

// Audio-rate frequency
void VCFQ_next_a(VCFQ* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* trigIn = IN(1);
    const float* freqIn = IN(2);
    float* out = OUT(0);

    const double sampleRate = SAMPLERATE;
    const double nyquistLimit = sampleRate * 0.49;

    const double q     = clamp_d(IN0(3), 0.5, 50.0);
    const double drive = clamp_d(IN0(4), 0.1, 20.0);
    const double invDrive = 1.0 / drive;
    const int mode     = unit->m_mode;
    const double R     = 1.0 / q;

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;
    float prevTrig = unit->m_prevTrig;

    const bool trigAudio = (INRATE(1) == calc_FullRate);

    for (int i = 0; i < inNumSamples; ++i) {
        double x = static_cast<double>(in[i]);

        float curTrig = trigAudio ? trigIn[i] : trigIn[0];
        if (curTrig > 0.0f && prevTrig <= 0.0f) {
            s1 += static_cast<double>(curTrig) * 1.0;
        }
        prevTrig = curTrig;

        const double freq = clamp_d(freqIn[i], 10.0, nyquistLimit);
        const double g = std::tan(kPi * freq / sampleRate);
        const double denom = 1.0 / (1.0 + R * g + g * g);

        const double v_hp = (x - (R + g) * s1 - s2) * denom;
        const double v_bp = g * v_hp + s1;
        const double v_lp = g * v_bp + s2;

        s1 = 2.0 * v_bp - s1;
        s2 = 2.0 * v_lp - s2;

        s1 = std::tanh(drive * s1 * 0.5) * (2.0 * invDrive);
        s2 = std::tanh(drive * s2 * 0.5) * (2.0 * invDrive);

        double y = 0.0;
        switch (mode) {
            case 0: y = v_lp; break;
            case 1: y = v_bp; break;
            case 2: y = v_hp; break;
            case 3: y = v_hp + v_lp; break;
        }

        out[i] = static_cast<float>(y);
    }

    unit->m_s1 = s1;
    unit->m_s2 = s2;
    unit->m_prevTrig = prevTrig;
}

} // namespace fs
