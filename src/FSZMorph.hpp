#pragma once

#include "SC_PlugIn.h"

namespace fs {

// ZSection: 2nd-order TPT bandpass/peaking formant resonator section
struct ZSection {
    double freq;
    double q;
    double gain;
};

// ZShape: Multiresonant shape definition (4 resonant sections + direct passband gain)
struct ZShape {
    const char* name;
    ZSection sections[4];
    double directGain;
};

// ZFilterBank: 4-section state-variable parallel resonator bank
struct ZFilterBank {
    double m_s1[4];
    double m_s2[4];
    double m_g[4];
    double m_R[4];
    double m_denom[4];
    double m_gain[4];
    double m_directGain;

    void init(int shapeIdx, double sampleRate);
    inline double process(double in) {
        double sum_bp = 0.0;
        for (int k = 0; k < 4; ++k) {
            double v_hp = (in - (m_R[k] + m_g[k]) * m_s1[k] - m_s2[k]) * m_denom[k];
            double v_bp = m_g[k] * v_hp + m_s1[k];
            double v_lp = m_g[k] * v_bp + m_s2[k];

            m_s1[k] = 2.0 * v_bp - m_s1[k];
            m_s2[k] = 2.0 * v_lp - m_s2[k];

            zapgremlins(m_s1[k]);
            zapgremlins(m_s2[k]);

            sum_bp += m_gain[k] * v_bp;
        }
        return sum_bp + m_directGain * in;
    }
};

// FSZMorph: Original digital multiresonant filter response morphing
// Reference concept: Rossum / E-mu Z-plane morphing (original DSP and presets, no proprietary ROM)
// Parallel processing of Shape A and Shape B with equal-gain response crossfade morph in [0, 1]
struct FSZMorph : public Unit {
    float m_morph;
    int m_shapeA;
    int m_shapeB;

    ZFilterBank m_bankA;
    ZFilterBank m_bankB;
};

void FSZMorph_Ctor(FSZMorph* unit);
void FSZMorph_next_k(FSZMorph* unit, int inNumSamples);
void FSZMorph_next_a(FSZMorph* unit, int inNumSamples);

} // namespace fs
