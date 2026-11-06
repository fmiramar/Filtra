#pragma once

#include "SC_PlugIn.h"

namespace fs {

// VCFQ: Serge-Style Variable-Q Ping Resonator & Multimode VCF
// Reference: Serge Tcherepnin VCFQ modular synthesizer filter core.
// 2-pole TPT state-variable filter with dedicated trigger/impulse ping excitation,
// dynamic Q control, and nonlinear AGC diode feedback saturation.
// Modes: 0 = Low-Pass, 1 = Band-Pass (classic ping), 2 = High-Pass, 3 = Notch.
struct VCFQ : public Unit {
    float m_freq;
    float m_q;
    float m_drive;
    int m_mode;

    double m_s1;
    double m_s2;
    float m_prevTrig;
};

void VCFQ_Ctor(VCFQ* unit);
void VCFQ_next_k(VCFQ* unit, int inNumSamples);
void VCFQ_next_a(VCFQ* unit, int inNumSamples);

} // namespace fs
