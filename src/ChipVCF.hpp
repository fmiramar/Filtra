#pragma once

#include "SC_PlugIn.h"

namespace fs {

// ChipVCF: Virtual Analog Model of the Solid State Micro Technology SSM2044 4-Pole Low-Pass VCF
// Reference: SSM2044 datasheet, Korg Polysix, Korg Mono/Poly, and PPG Wave VCF cores.
// 4-stage buffered differential ladder with internal gain-cell feedback saturation,
// partial bass-loss compensation, and singing sinusoidal limit cycle.
struct ChipVCF : public Unit {
    float m_freq;
    float m_res;
    float m_drive;

    // Four 1st-order trapezoidal integrator states
    double m_s1;
    double m_s2;
    double m_s3;
    double m_s4;
};

void ChipVCF_Ctor(ChipVCF* unit);
void ChipVCF_next_k(ChipVCF* unit, int inNumSamples);
void ChipVCF_next_a(ChipVCF* unit, int inNumSamples);

} // namespace fs
