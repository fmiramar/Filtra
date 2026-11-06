#pragma once

#include "SC_PlugIn.h"
#include "MS20Oversampler.hpp"

namespace ms20 {

struct MS20Diode : public Unit {
    float m_freq;
    float m_res;
    float m_drive;
    int m_mode; // 0 = LP, 1 = MS-20 HP
    int m_oversample; // 0 = 1x (off), 1 = 2x

    // Trapezoidal integrator state variables (capacitor voltages)
    double m_s1;
    double m_s2;

    // 2x Polyphase Halfband Oversampler
    Halfband2x m_os;
};

void MS20Diode_Ctor(MS20Diode* unit);

} // namespace ms20
