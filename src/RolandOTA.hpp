#pragma once

#include "SC_PlugIn.h"

namespace fs {

// RolandOTA: Virtual Analog Model of the Roland IR3109 4-Stage OTA Cascade
// Reference: Roland Juno-6/60, Jupiter-8, and SH-101 VCF filter cores.
// Four cascaded 1-pole OTA-C integrators with global negative feedback,
// differential pair hyperbolic tangent saturation, self-oscillation limit cycle,
// and optional bass-loss compensation.
struct RolandOTA : public Unit {
    float m_freq;
    float m_res;
    float m_drive;
    float m_resComp;

    // Four 1st-order trapezoidal integrator states
    double m_s1;
    double m_s2;
    double m_s3;
    double m_s4;
};

void RolandOTA_Ctor(RolandOTA* unit);
void RolandOTA_next_k(RolandOTA* unit, int inNumSamples);
void RolandOTA_next_a(RolandOTA* unit, int inNumSamples);

} // namespace fs
