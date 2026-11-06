#pragma once

#include "SC_PlugIn.h"

namespace fs {

// Polivoks: Virtual Analog Model of the Formanta Polivoks VCF
// Reference: Vladimir Kuzmin (1982), Formanta Polivoks synthesizer filter core;
// Stage P1: Linearized two-stage programmable-op-amp (K140UD12 / uA776) state-variable integrator cascade.
// Modes: 0 = Low-Pass (12 dB/oct), 1 = Band-Pass (6 dB/oct).
struct Polivoks : public Unit {
    float m_freq;
    float m_res;
    float m_drive;
    int m_mode; // 0 = LP, 1 = BP (init-only)

    // Integrator state variables (capacitor/op-amp integrator states)
    double m_s1; // Stage 1 integrator state (Bandpass node)
    double m_s2; // Stage 2 integrator state (Lowpass node)
};

using FSPolivoks = Polivoks;

void Polivoks_Ctor(Polivoks* unit);
void Polivoks_next_lp_k(Polivoks* unit, int inNumSamples);
void Polivoks_next_bp_k(Polivoks* unit, int inNumSamples);
void Polivoks_next_lp_a(Polivoks* unit, int inNumSamples);
void Polivoks_next_bp_a(Polivoks* unit, int inNumSamples);

inline void FSPolivoks_Ctor(FSPolivoks* unit) { Polivoks_Ctor(unit); }

} // namespace fs
