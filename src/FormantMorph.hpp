#pragma once

#include "SC_PlugIn.h"

namespace fs {

// FormantMorph: Coordinated Multi-Formant Vowel Bank with Continuous Log-Frequency Trajectory Morphing
// 3-formant parallel 2nd-order TPT bandpass filter bank supporting continuous log-frequency vowel morphing
// across 5 phonetic vowels ([a], [e], [i], [o], [u]) with formant bandwidth and frequency scaling.
struct FormantMorph : public Unit {
    float m_morph;
    int m_vowelA;
    int m_vowelB;
    float m_freqScale;
    float m_bwScale;

    // 3 parallel 2nd-order TPT bandpass sections
    double m_s1[3];
    double m_s2[3];
};

void FormantMorph_Ctor(FormantMorph* unit);
void FormantMorph_next_k(FormantMorph* unit, int inNumSamples);
void FormantMorph_next_a(FormantMorph* unit, int inNumSamples);

} // namespace fs
