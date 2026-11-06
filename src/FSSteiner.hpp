#pragma once

#include "SC_PlugIn.h"

namespace fs {

// FSSteiner: Virtual Analog Model of the Steiner-Parker Multimode Diode VCF
// Reference: Nyle Steiner (Electronic Design, 1974), "Voltage-tunable active filter features
// low, high and bandpass modes", and Yves Usson (YuSynth 2004) diode-limited Sallen-Key topology.
struct FSSteiner : public Unit {
    float m_freq;
    float m_res;
    float m_drive;
    int m_mode; // 0 = LP, 1 = BP, 2 = HP (init-only)

    // Capacitor state variables (physical capacitor voltages)
    double m_s1; // Capacitor C1 state (between Node 1 and feedback)
    double m_s2; // Capacitor C2 state (between Node 2 and ground/input)
};

void FSSteiner_Ctor(FSSteiner* unit);
void FSSteiner_next_lp_k(FSSteiner* unit, int inNumSamples);
void FSSteiner_next_bp_k(FSSteiner* unit, int inNumSamples);
void FSSteiner_next_hp_k(FSSteiner* unit, int inNumSamples);
void FSSteiner_next_lp_a(FSSteiner* unit, int inNumSamples);
void FSSteiner_next_bp_a(FSSteiner* unit, int inNumSamples);
void FSSteiner_next_hp_a(FSSteiner* unit, int inNumSamples);

} // namespace fs
