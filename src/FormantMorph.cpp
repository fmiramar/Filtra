#include "FormantMorph.hpp"
#include <cmath>
#include <algorithm>

namespace fs {

static constexpr double kPi = 3.14159265358979323846;

static inline double clamp_d(double val, double minVal, double maxVal) {
    return std::max(minVal, std::min(maxVal, val));
}

struct VowelData {
    double f[3];
    double bw[3];
};

static const VowelData kVowels[5] = {
    // 0: [a] (father)
    { { 730.0, 1090.0, 2440.0 }, { 130.0, 110.0, 160.0 } },
    // 1: [e] (bed)
    { { 530.0, 1840.0, 2480.0 }, { 90.0, 100.0, 120.0 } },
    // 2: [i] (bee)
    { { 270.0, 2290.0, 3010.0 }, { 60.0, 90.0, 150.0 } },
    // 3: [o] (bone)
    { { 570.0, 840.0, 2410.0 }, { 80.0, 70.0, 100.0 } },
    // 4: [u] (boot)
    { { 300.0, 870.0, 2240.0 }, { 65.0, 80.0, 110.0 } }
};

void FormantMorph_Ctor(FormantMorph* unit) {
    for (int k = 0; k < 3; ++k) {
        unit->m_s1[k] = 0.0;
        unit->m_s2[k] = 0.0;
    }

    unit->m_vowelA = std::max(0, std::min(4, static_cast<int>(IN0(2))));
    unit->m_vowelB = std::max(0, std::min(4, static_cast<int>(IN0(3))));

    bool isAudioRate = (INRATE(1) == calc_FullRate);
    if (isAudioRate) {
        SETCALC(FormantMorph_next_a);
    } else {
        SETCALC(FormantMorph_next_k);
    }

    OUT0(0) = 0.0f;
}

void FormantMorph_next_k(FormantMorph* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);

    const double sampleRate = SAMPLERATE;
    const double nyquistLimit = sampleRate * 0.49;

    const double morph = clamp_d(IN0(1), 0.0, 1.0);
    const int vA = unit->m_vowelA;
    const int vB = unit->m_vowelB;
    const double freqScale = clamp_d(IN0(4), 0.1, 5.0);
    const double bwScale   = clamp_d(IN0(5), 0.1, 5.0);

    const VowelData& dataA = kVowels[vA];
    const VowelData& dataB = kVowels[vB];

    double g[3];
    double R[3];
    double denom[3];

    for (int k = 0; k < 3; ++k) {
        // Continuous log-frequency interpolation
        const double logF = (1.0 - morph) * std::log(dataA.f[k]) + morph * std::log(dataB.f[k]);
        const double fk = clamp_d(std::exp(logF) * freqScale, 20.0, nyquistLimit);

        // Linear bandwidth interpolation
        const double bw = (1.0 - morph) * dataA.bw[k] + morph * dataB.bw[k];
        const double bwK = clamp_d(bw * bwScale, 10.0, fk * 2.0);

        const double Q = fk / bwK;
        R[k] = 1.0 / std::max(0.1, Q);
        g[k] = std::tan(kPi * fk / sampleRate);
        denom[k] = 1.0 / (1.0 + R[k] * g[k] + g[k] * g[k]);
    }

    double s1_0 = unit->m_s1[0], s2_0 = unit->m_s2[0];
    double s1_1 = unit->m_s1[1], s2_1 = unit->m_s2[1];
    double s1_2 = unit->m_s1[2], s2_2 = unit->m_s2[2];

    for (int i = 0; i < inNumSamples; ++i) {
        const double x = static_cast<double>(in[i]);

        // Formant 1
        const double hp0 = (x - (R[0] + g[0]) * s1_0 - s2_0) * denom[0];
        const double bp0 = g[0] * hp0 + s1_0;
        const double lp0 = g[0] * bp0 + s2_0;
        s1_0 = 2.0 * bp0 - s1_0;
        s2_0 = 2.0 * lp0 - s2_0;

        // Formant 2
        const double hp1 = (x - (R[1] + g[1]) * s1_1 - s2_1) * denom[1];
        const double bp1 = g[1] * hp1 + s1_1;
        const double lp1 = g[1] * bp1 + s2_1;
        s1_1 = 2.0 * bp1 - s1_1;
        s2_1 = 2.0 * lp1 - s2_1;

        // Formant 3
        const double hp2 = (x - (R[2] + g[2]) * s1_2 - s2_2) * denom[2];
        const double bp2 = g[2] * hp2 + s1_2;
        const double lp2 = g[2] * bp2 + s2_2;
        s1_2 = 2.0 * bp2 - s1_2;
        s2_2 = 2.0 * lp2 - s2_2;

        // Sum formant bandpass responses with equalizing gains
        const double y = bp0 * 1.0 + bp1 * 0.7 + bp2 * 0.4;
        out[i] = static_cast<float>(y);
    }

    unit->m_s1[0] = s1_0; unit->m_s2[0] = s2_0;
    unit->m_s1[1] = s1_1; unit->m_s2[1] = s2_1;
    unit->m_s1[2] = s1_2; unit->m_s2[2] = s2_2;
}

void FormantMorph_next_a(FormantMorph* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* morphIn = IN(1);
    float* out = OUT(0);

    const double sampleRate = SAMPLERATE;
    const double nyquistLimit = sampleRate * 0.49;

    const int vA = unit->m_vowelA;
    const int vB = unit->m_vowelB;
    const double freqScale = clamp_d(IN0(4), 0.1, 5.0);
    const double bwScale   = clamp_d(IN0(5), 0.1, 5.0);

    const VowelData& dataA = kVowels[vA];
    const VowelData& dataB = kVowels[vB];

    double s1_0 = unit->m_s1[0], s2_0 = unit->m_s2[0];
    double s1_1 = unit->m_s1[1], s2_1 = unit->m_s2[1];
    double s1_2 = unit->m_s1[2], s2_2 = unit->m_s2[2];

    for (int i = 0; i < inNumSamples; ++i) {
        const double x = static_cast<double>(in[i]);
        const double morph = clamp_d(morphIn[i], 0.0, 1.0);

        double g[3];
        double R[3];
        double denom[3];

        for (int k = 0; k < 3; ++k) {
            const double logF = (1.0 - morph) * std::log(dataA.f[k]) + morph * std::log(dataB.f[k]);
            const double fk = clamp_d(std::exp(logF) * freqScale, 20.0, nyquistLimit);
            const double bw = (1.0 - morph) * dataA.bw[k] + morph * dataB.bw[k];
            const double bwK = clamp_d(bw * bwScale, 10.0, fk * 2.0);

            const double Q = fk / bwK;
            R[k] = 1.0 / std::max(0.1, Q);
            g[k] = std::tan(kPi * fk / sampleRate);
            denom[k] = 1.0 / (1.0 + R[k] * g[k] + g[k] * g[k]);
        }

        const double hp0 = (x - (R[0] + g[0]) * s1_0 - s2_0) * denom[0];
        const double bp0 = g[0] * hp0 + s1_0;
        const double lp0 = g[0] * bp0 + s2_0;
        s1_0 = 2.0 * bp0 - s1_0;
        s2_0 = 2.0 * lp0 - s2_0;

        const double hp1 = (x - (R[1] + g[1]) * s1_1 - s2_1) * denom[1];
        const double bp1 = g[1] * hp1 + s1_1;
        const double lp1 = g[1] * bp1 + s2_1;
        s1_1 = 2.0 * bp1 - s1_1;
        s2_1 = 2.0 * lp1 - s2_1;

        const double hp2 = (x - (R[2] + g[2]) * s1_2 - s2_2) * denom[2];
        const double bp2 = g[2] * hp2 + s1_2;
        const double lp2 = g[2] * bp2 + s2_2;
        s1_2 = 2.0 * bp2 - s1_2;
        s2_2 = 2.0 * lp2 - s2_2;

        const double y = bp0 * 1.0 + bp1 * 0.7 + bp2 * 0.4;
        out[i] = static_cast<float>(y);
    }

    unit->m_s1[0] = s1_0; unit->m_s2[0] = s2_0;
    unit->m_s1[1] = s1_1; unit->m_s2[1] = s2_1;
    unit->m_s1[2] = s1_2; unit->m_s2[2] = s2_2;
}

} // namespace fs
