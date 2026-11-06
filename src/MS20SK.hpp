#pragma once

#include "SC_PlugIn.h"

namespace ms20 {

struct MS20SK : public Unit {
    float m_freq;
    float m_res;
    int m_mode; // 0 = LP, 1 = MS-20 HP

    // Monic biquad coefficients: y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2]
    double m_b0;
    double m_b1;
    double m_b2;
    double m_a1;
    double m_a2;

    // Transposed Direct Form II state variables
    double m_s1;
    double m_s2;
};

void MS20SK_Ctor(MS20SK* unit);
void MS20SK_next_k(MS20SK* unit, int inNumSamples);
void MS20SK_next_lp_a(MS20SK* unit, int inNumSamples);
void MS20SK_next_hp_a(MS20SK* unit, int inNumSamples);

} // namespace ms20
