#include "RolandOTA.hpp"
#include <cmath>
#include <algorithm>

namespace fs {

static constexpr double kPi = 3.14159265358979323846;

static inline double clamp_d(double val, double minVal, double maxVal) {
    return std::max(minVal, std::min(maxVal, val));
}

void RolandOTA_Ctor(RolandOTA* unit) {
    unit->m_s1 = 0.0;
    unit->m_s2 = 0.0;
    unit->m_s3 = 0.0;
    unit->m_s4 = 0.0;

    bool isAudioRate = (INRATE(1) == calc_FullRate);
    if (isAudioRate) {
        SETCALC(RolandOTA_next_a);
    } else {
        SETCALC(RolandOTA_next_k);
    }

    OUT0(0) = 0.0f;
}

// Control-rate cutoff frequency
void RolandOTA_next_k(RolandOTA* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);

    const double sampleRate = SAMPLERATE;
    const double nyquistLimit = sampleRate * 0.49;

    const double freq    = clamp_d(IN0(1), 10.0, nyquistLimit);
    const double res     = clamp_d(IN0(2), 0.0, 1.2);
    const double drive   = clamp_d(IN0(3), 0.01, 20.0);
    const double resComp = clamp_d(IN0(4), 0.0, 1.0);
    const double invDrive = 1.0 / drive;

    // 1-pole TPT prewarped integrator gain
    const double g = std::tan(kPi * freq / sampleRate);
    const double G = g / (1.0 + g);
    const double inv1pG = 1.0 / (1.0 + g);
    const double G2 = G * G;
    const double G3 = G2 * G;
    const double G4 = G3 * G;

    // Feedback resonance gain
    const double kres = res * 1.0;
    const double kFeedback = 4.0 * kres;
    const double compGain = 1.0 + kFeedback * resComp;
    const double denom = 1.0 / (1.0 + kFeedback * G4);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;
    double s3 = unit->m_s3;
    double s4 = unit->m_s4;

    for (int i = 0; i < inNumSamples; ++i) {
        const double x = static_cast<double>(in[i]) * compGain;

        const double S1 = s1 * inv1pG;
        const double S2 = s2 * inv1pG;
        const double S3 = s3 * inv1pG;
        const double S4 = s4 * inv1pG;

        const double S_total = G3 * S1 + G2 * S2 + G * S3 + S4;

        // Exact linear prediction for stage 4 output
        const double y4_lin = (G4 * x + S_total) * denom;

        // Saturated feedback through differential pair OTA
        const double fb = kFeedback * (std::tanh(drive * y4_lin) * invDrive);
        const double u1 = x - fb;

        // 4-stage OTA cascade with hyperbolic tangent saturation
        double y1 = G * u1 + S1;
        y1 = std::tanh(drive * y1) * invDrive;

        double y2 = G * y1 + S2;
        y2 = std::tanh(drive * y2) * invDrive;

        double y3 = G * y2 + S3;
        y3 = std::tanh(drive * y3) * invDrive;

        double y4 = G * y3 + S4;
        y4 = std::tanh(drive * y4) * invDrive;

        // Trapezoidal integrator state updates
        s1 = 2.0 * y1 - s1;
        s2 = 2.0 * y2 - s2;
        s3 = 2.0 * y3 - s3;
        s4 = 2.0 * y4 - s4;

        // Bound states against extreme runaway during deep self-oscillation
        s1 = std::tanh(drive * s1 * 0.5) * (2.0 * invDrive);
        s2 = std::tanh(drive * s2 * 0.5) * (2.0 * invDrive);
        s3 = std::tanh(drive * s3 * 0.5) * (2.0 * invDrive);
        s4 = std::tanh(drive * s4 * 0.5) * (2.0 * invDrive);

        out[i] = static_cast<float>(y4);
    }

    unit->m_s1 = s1;
    unit->m_s2 = s2;
    unit->m_s3 = s3;
    unit->m_s4 = s4;
}

// Audio-rate cutoff frequency
void RolandOTA_next_a(RolandOTA* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* freqIn = IN(1);
    float* out = OUT(0);

    const double sampleRate = SAMPLERATE;
    const double nyquistLimit = sampleRate * 0.49;

    const double res     = clamp_d(IN0(2), 0.0, 1.2);
    const double drive   = clamp_d(IN0(3), 0.01, 20.0);
    const double resComp = clamp_d(IN0(4), 0.0, 1.0);
    const double invDrive = 1.0 / drive;

    const double kres = res * 1.0;
    const double kFeedback = 4.0 * kres;
    const double compGain = 1.0 + kFeedback * resComp;

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;
    double s3 = unit->m_s3;
    double s4 = unit->m_s4;

    for (int i = 0; i < inNumSamples; ++i) {
        const double x = static_cast<double>(in[i]) * compGain;

        const double freq = clamp_d(freqIn[i], 10.0, nyquistLimit);
        const double g = std::tan(kPi * freq / sampleRate);
        const double G = g / (1.0 + g);
        const double inv1pG = 1.0 / (1.0 + g);
        const double G2 = G * G;
        const double G3 = G2 * G;
        const double G4 = G3 * G;

        const double denom = 1.0 / (1.0 + kFeedback * G4);

        const double S1 = s1 * inv1pG;
        const double S2 = s2 * inv1pG;
        const double S3 = s3 * inv1pG;
        const double S4 = s4 * inv1pG;

        const double S_total = G3 * S1 + G2 * S2 + G * S3 + S4;

        const double y4_lin = (G4 * x + S_total) * denom;
        const double fb = kFeedback * (std::tanh(drive * y4_lin) * invDrive);
        const double u1 = x - fb;

        double y1 = G * u1 + S1;
        y1 = std::tanh(drive * y1) * invDrive;

        double y2 = G * y1 + S2;
        y2 = std::tanh(drive * y2) * invDrive;

        double y3 = G * y2 + S3;
        y3 = std::tanh(drive * y3) * invDrive;

        double y4 = G * y3 + S4;
        y4 = std::tanh(drive * y4) * invDrive;

        s1 = 2.0 * y1 - s1;
        s2 = 2.0 * y2 - s2;
        s3 = 2.0 * y3 - s3;
        s4 = 2.0 * y4 - s4;

        s1 = std::tanh(drive * s1 * 0.5) * (2.0 * invDrive);
        s2 = std::tanh(drive * s2 * 0.5) * (2.0 * invDrive);
        s3 = std::tanh(drive * s3 * 0.5) * (2.0 * invDrive);
        s4 = std::tanh(drive * s4 * 0.5) * (2.0 * invDrive);

        out[i] = static_cast<float>(y4);
    }

    unit->m_s1 = s1;
    unit->m_s2 = s2;
    unit->m_s3 = s3;
    unit->m_s4 = s4;
}

} // namespace fs
