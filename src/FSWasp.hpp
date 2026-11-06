#pragma once

#include "SC_PlugIn.h"

namespace fs {

// FSWasp: Virtual Analog Model of the EDP Wasp VCF (Stage W1/W2: Linear and Nonlinear Circuit Model)
// Reference: L. Köper, M. Holters, F. Esqueda, J. D. Parker (2022),
// "A Virtual Analog Model of the EDP Wasp VCF", DAFx 2022, Sections 2-4.
struct FSWasp : public Unit {
    float m_freq;
    float m_res;
    float m_drive;
    int m_mode; // 0 = LP, 1 = BP, 2 = HP (init-only)

    // Trapezoidal integrator states (physical integrator capacitor charges)
    double m_s1; // First integrator state (Band-Pass node vIC3)
    double m_s2; // Second integrator state (Low-Pass node vIC5)
};

void FSWasp_Ctor(FSWasp* unit);
void FSWasp_next_lp_k(FSWasp* unit, int inNumSamples);
void FSWasp_next_bp_k(FSWasp* unit, int inNumSamples);
void FSWasp_next_hp_k(FSWasp* unit, int inNumSamples);
void FSWasp_next_lp_a(FSWasp* unit, int inNumSamples);
void FSWasp_next_bp_a(FSWasp* unit, int inNumSamples);
void FSWasp_next_hp_a(FSWasp* unit, int inNumSamples);

} // namespace fs
