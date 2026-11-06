#pragma once

#include "SC_PlugIn.h"

namespace fs {

// APSection: 2nd-order TPT All-Pass Filter Section
// Transfer function: H_ap(s) = (s^2 - R*w0*s + w0^2) / (s^2 + R*w0*s + w0^2)
// In TPT state-variable form: v_ap = v_in - 2 * R * v_bp
// Satisfies |H_ap(e^jw)| == 1.000000 identically across all frequencies.
struct APSection {
    double m_s1;
    double m_s2;

    void init() {
        m_s1 = 0.0;
        m_s2 = 0.0;
    }

    inline double process(double in, double g, double R, double denom) {
        double v_hp = (in - (R + g) * m_s1 - m_s2) * denom;
        double v_bp = g * v_hp + m_s1;
        double v_lp = g * v_bp + m_s2;

        m_s1 = 2.0 * v_bp - m_s1;
        m_s2 = 2.0 * v_lp - m_s2;

        zapgremlins(m_s1);
        zapgremlins(m_s2);

        return in - 2.0 * R * v_bp;
    }
};

// Dispersion: Dispersive All-Pass Group-Delay Filter
// Reference: Abel and Smith (DAFx 2006), "Robust Design of Very High-Order Allpass Dispersion Filters"
// Four cascaded 2nd-order all-pass sections with geometric frequency distribution around center
struct Dispersion : public Unit {
    float m_center;
    float m_spread;
    float m_q;

    APSection m_sections[4];
};

void Dispersion_Ctor(Dispersion* unit);
void Dispersion_next_k(Dispersion* unit, int inNumSamples);
void Dispersion_next_a(Dispersion* unit, int inNumSamples);

} // namespace fs
