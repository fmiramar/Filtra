#include "FSZMorph.hpp"
#include <cmath>
#include <algorithm>

namespace fs {

static const ZShape kShapes[6] = {
    // 0: Vowel A (Open Father)
    { "VowelA", { { 730.0, 6.0, 1.00 }, { 1090.0, 7.0, 0.65 }, { 2440.0, 9.0, 0.35 }, { 3500.0, 8.0, 0.20 } }, 0.15 },
    // 1: Vowel I (Front High Bee)
    { "VowelI", { { 270.0, 5.0, 1.00 }, { 2290.0, 10.0, 0.70 }, { 3010.0, 10.0, 0.40 }, { 4200.0, 8.0, 0.15 } }, 0.15 },
    // 2: Vowel U (Back High Boot)
    { "VowelU", { { 300.0, 5.0, 1.00 }, { 870.0, 6.0, 0.70 }, { 2250.0, 8.0, 0.35 }, { 3100.0, 8.0, 0.15 } }, 0.15 },
    // 3: Deep Comb (Destructive Notch Interference)
    { "DeepComb", { { 220.0, 8.0, 1.00 }, { 660.0, 12.0, -0.70 }, { 1320.0, 10.0, 0.60 }, { 2640.0, 14.0, -0.50 } }, 0.25 },
    // 4: Metallic Bell (Inharmonic Resonant Modes)
    { "MetallicBell", { { 440.0, 15.0, 0.90 }, { 980.0, 20.0, 0.80 }, { 1790.0, 22.0, 0.60 }, { 3280.0, 25.0, 0.40 } }, 0.05 },
    // 5: Acoustic Body (Warm Low Modes)
    { "AcousticBody", { { 110.0, 4.0, 0.90 }, { 220.0, 5.0, 0.80 }, { 450.0, 6.0, 0.60 }, { 900.0, 8.0, 0.40 } }, 0.30 }
};

static constexpr int kNumShapes = 6;

void ZFilterBank::init(int shapeIdx, double sampleRate) {
    int idx = std::max(0, std::min(kNumShapes - 1, shapeIdx));
    const ZShape& shape = kShapes[idx];
    m_directGain = shape.directGain;

    for (int k = 0; k < 4; ++k) {
        m_s1[k] = 0.0;
        m_s2[k] = 0.0;
        double fc = std::max(10.0, std::min(sampleRate * 0.49, shape.sections[k].freq));
        m_g[k] = std::tan(M_PI * fc / sampleRate);
        m_R[k] = 1.0 / std::max(0.1, shape.sections[k].q);
        m_denom[k] = 1.0 / (1.0 + m_R[k] * m_g[k] + m_g[k] * m_g[k]);
        m_gain[k] = shape.sections[k].gain;
    }
}

void FSZMorph_Ctor(FSZMorph* unit) {
    unit->m_morph = IN0(1);
    unit->m_shapeA = static_cast<int>(IN0(2));
    unit->m_shapeB = static_cast<int>(IN0(3));

    unit->m_bankA.init(unit->m_shapeA, SAMPLERATE);
    unit->m_bankB.init(unit->m_shapeB, SAMPLERATE);

    bool isAudioRateMorph = (INRATE(1) == calc_FullRate);
    if (isAudioRateMorph) {
        SETCALC(FSZMorph_next_a);
    } else {
        SETCALC(FSZMorph_next_k);
    }

    (unit->mCalcFunc)(unit, 1);
}

void FSZMorph_next_k(FSZMorph* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);

    float m = std::max(0.0f, std::min(1.0f, IN0(1)));
    float wA = 1.0f - m;
    float wB = m;

    for (int i = 0; i < inNumSamples; ++i) {
        double inVal = in[i];
        double yA = unit->m_bankA.process(inVal);
        double yB = unit->m_bankB.process(inVal);
        out[i] = static_cast<float>(wA * yA + wB * yB);
    }
}

void FSZMorph_next_a(FSZMorph* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* morphIn = IN(1);
    float* out = OUT(0);

    for (int i = 0; i < inNumSamples; ++i) {
        float m = std::max(0.0f, std::min(1.0f, morphIn[i]));
        float wA = 1.0f - m;
        float wB = m;
        double inVal = in[i];
        double yA = unit->m_bankA.process(inVal);
        double yB = unit->m_bankB.process(inVal);
        out[i] = static_cast<float>(wA * yA + wB * yB);
    }
}

} // namespace fs
