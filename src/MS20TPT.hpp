#pragma once

#include "SC_PlugIn.h"

namespace ms20 {

struct MS20TPT : public Unit {
    float m_freq;
    float m_res;
    int m_mode; // 0 = LP, 1 = MS-20 HP

    // TPT parameters (algebraic zero-delay matrix elements)
    double m_g;
    double m_m00;
    double m_m01;
    double m_m10;
    double m_m11;
    double m_b00; // RHS input scale 1
    double m_b10; // RHS input scale 2

    // Trapezoidal integrator state variables (capacitor voltages)
    double m_s1;
    double m_s2;
};

void MS20TPT_Ctor(MS20TPT* unit);
void MS20TPT_next_lp(MS20TPT* unit, int inNumSamples);
void MS20TPT_next_hp(MS20TPT* unit, int inNumSamples);
void MS20TPT_next_lp_a(MS20TPT* unit, int inNumSamples);
void MS20TPT_next_hp_a(MS20TPT* unit, int inNumSamples);

} // namespace ms20
