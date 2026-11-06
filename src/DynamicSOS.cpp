#include "DynamicSOS.hpp"
#include <cmath>
#include <algorithm>

namespace fs {

static constexpr double kPi = 3.14159265358979323846;

static inline double clamp_d(double val, double minVal, double maxVal) {
    return std::max(minVal, std::min(maxVal, val));
}

static inline void getMixCoeffs(int mode, double gainDB, double R, double& mx, double& mhp, double& mbp, double& mlp) {
    mx = 0.0;
    mhp = 0.0;
    mbp = 0.0;
    mlp = 0.0;
    switch (mode) {
        case 0: // LowPass (24 dB/oct cascade)
            mlp = 1.0;
            break;
        case 1: // HighPass (24 dB/oct cascade)
            mhp = 1.0;
            break;
        case 2: // BandPass (0 dB peak gain at fc, steep 4-pole skirts)
            mbp = R;
            break;
        case 3: // Notch (steep cascaded null)
            mhp = 1.0;
            mlp = 1.0;
            break;
        case 4: { // Peak / Bell EQ
            double lin = std::pow(10.0, gainDB / 40.0); // Per-section gain for 2 cascaded sections
            mx = 1.0;
            mbp = (lin - 1.0) * R;
            break;
        }
        case 5: { // LowShelf
            double lin = std::pow(10.0, gainDB / 40.0);
            mx = 1.0;
            mlp = lin - 1.0;
            break;
        }
        case 6: { // HighShelf
            double lin = std::pow(10.0, gainDB / 40.0);
            mx = 1.0;
            mhp = lin - 1.0;
            break;
        }
        default:
            mlp = 1.0;
            break;
    }
}

void DynamicSOS_Ctor(DynamicSOS* unit) {
    unit->m_s1_1 = 0.0;
    unit->m_s2_1 = 0.0;
    unit->m_s1_2 = 0.0;
    unit->m_s2_2 = 0.0;
    unit->m_mode = std::max(0, std::min(6, static_cast<int>(IN0(4))));

    bool isAudioRate = (INRATE(1) == calc_FullRate);
    if (isAudioRate) {
        SETCALC(DynamicSOS_next_a);
    } else {
        SETCALC(DynamicSOS_next_k);
    }

    OUT0(0) = 0.0f;
}

// Control-rate frequency modulation
void DynamicSOS_next_k(DynamicSOS* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);

    const double sampleRate = SAMPLERATE;
    const double nyquistLimit = sampleRate * 0.49;

    const double freq   = clamp_d(IN0(1), 10.0, nyquistLimit);
    const double q      = clamp_d(IN0(2), 0.1, 50.0);
    const double gainDB = clamp_d(IN0(3), -36.0, 36.0);
    const int mode      = unit->m_mode;

    const double g = std::tan(kPi * freq / sampleRate);
    const double R = 1.0 / q;
    const double denom = 1.0 / (1.0 + R * g + g * g);

    double mx, mhp, mbp, mlp;
    getMixCoeffs(mode, gainDB, R, mx, mhp, mbp, mlp);

    double s1_1 = unit->m_s1_1;
    double s2_1 = unit->m_s2_1;
    double s1_2 = unit->m_s1_2;
    double s2_2 = unit->m_s2_2;

    for (int i = 0; i < inNumSamples; ++i) {
        double x = static_cast<double>(in[i]);

        // Section 1
        const double v_hp1 = (x - (R + g) * s1_1 - s2_1) * denom;
        const double v_bp1 = g * v_hp1 + s1_1;
        const double v_lp1 = g * v_bp1 + s2_1;
        s1_1 = 2.0 * v_bp1 - s1_1;
        s2_1 = 2.0 * v_lp1 - s2_1;
        const double y1 = mx * x + mhp * v_hp1 + mbp * v_bp1 + mlp * v_lp1;

        // Section 2 (cascaded)
        const double v_hp2 = (y1 - (R + g) * s1_2 - s2_2) * denom;
        const double v_bp2 = g * v_hp2 + s1_2;
        const double v_lp2 = g * v_bp2 + s2_2;
        s1_2 = 2.0 * v_bp2 - s1_2;
        s2_2 = 2.0 * v_lp2 - s2_2;
        const double y2 = mx * y1 + mhp * v_hp2 + mbp * v_bp2 + mlp * v_lp2;

        out[i] = static_cast<float>(y2);
    }

    unit->m_s1_1 = s1_1;
    unit->m_s2_1 = s2_1;
    unit->m_s1_2 = s1_2;
    unit->m_s2_2 = s2_2;
}

// Audio-rate frequency modulation
void DynamicSOS_next_a(DynamicSOS* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* freqIn = IN(1);
    float* out = OUT(0);

    const double sampleRate = SAMPLERATE;
    const double nyquistLimit = sampleRate * 0.49;

    const double q      = clamp_d(IN0(2), 0.1, 50.0);
    const double gainDB = clamp_d(IN0(3), -36.0, 36.0);
    const int mode      = unit->m_mode;
    const double R      = 1.0 / q;

    double mx, mhp, mbp, mlp;
    getMixCoeffs(mode, gainDB, R, mx, mhp, mbp, mlp);

    double s1_1 = unit->m_s1_1;
    double s2_1 = unit->m_s2_1;
    double s1_2 = unit->m_s1_2;
    double s2_2 = unit->m_s2_2;

    for (int i = 0; i < inNumSamples; ++i) {
        double x = static_cast<double>(in[i]);

        const double freq = clamp_d(freqIn[i], 10.0, nyquistLimit);
        const double g = std::tan(kPi * freq / sampleRate);
        const double denom = 1.0 / (1.0 + R * g + g * g);

        // Section 1
        const double v_hp1 = (x - (R + g) * s1_1 - s2_1) * denom;
        const double v_bp1 = g * v_hp1 + s1_1;
        const double v_lp1 = g * v_bp1 + s2_1;
        s1_1 = 2.0 * v_bp1 - s1_1;
        s2_1 = 2.0 * v_lp1 - s2_1;
        const double y1 = mx * x + mhp * v_hp1 + mbp * v_bp1 + mlp * v_lp1;

        // Section 2 (cascaded)
        const double v_hp2 = (y1 - (R + g) * s1_2 - s2_2) * denom;
        const double v_bp2 = g * v_hp2 + s1_2;
        const double v_lp2 = g * v_bp2 + s2_2;
        s1_2 = 2.0 * v_bp2 - s1_2;
        s2_2 = 2.0 * v_lp2 - s2_2;
        const double y2 = mx * y1 + mhp * v_hp2 + mbp * v_bp2 + mlp * v_lp2;

        out[i] = static_cast<float>(y2);
    }

    unit->m_s1_1 = s1_1;
    unit->m_s2_1 = s2_1;
    unit->m_s1_2 = s1_2;
    unit->m_s2_2 = s2_2;
}

} // namespace fs
