#pragma once

#include "SC_PlugIn.h"

namespace fs {

// CS80: Yamaha CS-80 Series Independently Resonant High-Pass -> Low-Pass Filter Pair
// Reference: Yamaha CS-50/60/80 VCF voice architecture (IG00153 / IG00156 custom ICs).
// Cascades an independent 2-pole resonant High-Pass stage into an independent 2-pole resonant Low-Pass stage
// with inter-stage nonlinear drive saturation.
struct CS80 : public Unit {
    float m_hpFreq;
    float m_hpRes;
    float m_lpFreq;
    float m_lpRes;
    float m_drive;

    // High-Pass SVF TPT capacitor states
    double m_hp_s1;
    double m_hp_s2;

    // Low-Pass SVF TPT capacitor states
    double m_lp_s1;
    double m_lp_s2;
};

void CS80_Ctor(CS80* unit);
void CS80_next_kk(CS80* unit, int inNumSamples);
void CS80_next_ak(CS80* unit, int inNumSamples);
void CS80_next_ka(CS80* unit, int inNumSamples);
void CS80_next_aa(CS80* unit, int inNumSamples);

} // namespace fs
