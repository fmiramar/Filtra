#pragma once

#include "SC_PlugIn.h"

namespace fs {

// DynamicSOS: Modulation-Safe Cascaded Biquad (2x 2nd-order TPT SVF Sections)
// Eliminates the transient instability, pops, and coefficient explosion of
// standard Direct-Form biquads (SOS) under fast audio-rate and control-rate modulation.
// Modes:
//   0 = LowPass (4-pole 24 dB/oct cascade)
//   1 = HighPass (4-pole 24 dB/oct cascade)
//   2 = BandPass (4-pole cascade)
//   3 = Notch (cascaded notch)
//   4 = Peak / Bell EQ
//   5 = LowShelf
//   6 = HighShelf
struct DynamicSOS : public Unit {
    float m_freq;
    float m_q;
    float m_gain;
    int m_mode;

    // Section 1 states
    double m_s1_1;
    double m_s2_1;

    // Section 2 states
    double m_s1_2;
    double m_s2_2;
};

void DynamicSOS_Ctor(DynamicSOS* unit);
void DynamicSOS_next_k(DynamicSOS* unit, int inNumSamples);
void DynamicSOS_next_a(DynamicSOS* unit, int inNumSamples);

} // namespace fs
