#pragma once

#include "SC_PlugIn.h"

namespace fs {

// FSPolivoks: Virtual Analog Model of the Formanta Polivoks VCF
// Reference: Vladimir Kuzmin (1982), Formanta Polivoks synthesizer filter core;
// Stage P1: Linearized two-stage programmable-op-amp (K140UD12 / uA776) state-variable integrator cascade.
// Modes: 0 = Low-Pass (12 dB/oct), 1 = Band-Pass (6 dB/oct).
struct FSPolivoks : public Unit {
    float m_freq;
    float m_res;
    float m_drive;
    int m_mode; // 0 = LP, 1 = BP (init-only)

    // Integrator state variables (capacitor/op-amp integrator states)
    double m_s1; // Stage 1 integrator state (Bandpass node)
    double m_s2; // Stage 2 integrator state (Lowpass node)
};

void FSPolivoks_Ctor(FSPolivoks* unit);
void FSPolivoks_next_lp_k(FSPolivoks* unit, int inNumSamples);
void FSPolivoks_next_bp_k(FSPolivoks* unit, int inNumSamples);
void FSPolivoks_next_lp_a(FSPolivoks* unit, int inNumSamples);
void FSPolivoks_next_bp_a(FSPolivoks* unit, int inNumSamples);

} // namespace fs
