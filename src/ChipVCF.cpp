#include "ChipVCF.hpp"
#include <cmath>
#include <algorithm>

namespace fs {

static constexpr double kPi = 3.14159265358979323846;

static inline double clamp_d(double val, double minVal, double maxVal) {
    return std::max(minVal, std::min(maxVal, val));
}

void ChipVCF_Ctor(ChipVCF* unit) {
    unit->m_s1 = 0.0;
    unit->m_s2 = 0.0;
    unit->m_s3 = 0.0;
    unit->m_s4 = 0.0;

    bool isAudioRate = (INRATE(1) == calc_FullRate);
    if (isAudioRate) {
        SETCALC(ChipVCF_next_a);
    } else {
        SETCALC(ChipVCF_next_k);
    }

    OUT0(0) = 0.0f;
}

// Control-rate cutoff frequency
void ChipVCF_next_k(ChipVCF* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);

    const double sampleRate = SAMPLERATE;
    const double nyquistLimit = sampleRate * 0.49;

    const double freq  = clamp_d(IN0(1), 10.0, nyquistLimit);
    const double res   = clamp_d(IN0(2), 0.0, 1.2);
    const double drive = clamp_d(IN0(3), 0.01, 20.0);
    const double invDrive = 1.0 / drive;

    const double g = std::tan(kPi * freq / sampleRate);
    const double G = g / (1.0 + g);
    const double inv1pG = 1.0 / (1.0 + g);
    const double G2 = G * G;
    const double G3 = G2 * G;
    const double G4 = G3 * G;

    // SSM2044 resonance scaling: 4.0 * res
    const double kres = res * 4.0;
    // SSM2044 internal partial bass compensation network
    const double compGain = 1.0 + 2.5 * res;
    const double denom = 1.0 / (1.0 + kres * G4);

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

        const double S_tot = G3 * S1 + G2 * S2 + G * S3 + S4;

        // Exact linear prediction for stage 4
        const double y4_lin = (G4 * x + S_tot) * denom;

        // Nonlinear gain-cell feedback
        const double fb = kres * (std::tanh(drive * y4_lin) * invDrive);
        const double u1 = x - fb;

        // 4 differential stages with soft saturation
        double y1 = std::tanh(drive * (G * u1 + S1)) * invDrive;
        double y2 = std::tanh(drive * (G * y1 + S2)) * invDrive;
        double y3 = std::tanh(drive * (G * y2 + S3)) * invDrive;
        double y4 = std::tanh(drive * (G * y3 + S4)) * invDrive;

        // State update with limiting against divergence
        s1 = std::tanh(drive * (2.0 * y1 - s1) * 0.5) * (2.0 * invDrive);
        s2 = std::tanh(drive * (2.0 * y2 - s2) * 0.5) * (2.0 * invDrive);
        s3 = std::tanh(drive * (2.0 * y3 - s3) * 0.5) * (2.0 * invDrive);
        s4 = std::tanh(drive * (2.0 * y4 - s4) * 0.5) * (2.0 * invDrive);

        out[i] = static_cast<float>(y4);
    }

    unit->m_s1 = s1;
    unit->m_s2 = s2;
    unit->m_s3 = s3;
    unit->m_s4 = s4;
}

// Audio-rate cutoff frequency
void ChipVCF_next_a(ChipVCF* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* freqIn = IN(1);
    float* out = OUT(0);

    const double sampleRate = SAMPLERATE;
    const double nyquistLimit = sampleRate * 0.49;

    const double res   = clamp_d(IN0(2), 0.0, 1.2);
    const double drive = clamp_d(IN0(3), 0.01, 20.0);
    const double invDrive = 1.0 / drive;

    const double kres = res * 4.0;
    const double compGain = 1.0 + 2.5 * res;

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

        const double denom = 1.0 / (1.0 + kres * G4);

        const double S1 = s1 * inv1pG;
        const double S2 = s2 * inv1pG;
        const double S3 = s3 * inv1pG;
        const double S4 = s4 * inv1pG;

        const double S_tot = G3 * S1 + G2 * S2 + G * S3 + S4;

        const double y4_lin = (G4 * x + S_tot) * denom;
        const double fb = kres * (std::tanh(drive * y4_lin) * invDrive);
        const double u1 = x - fb;

        double y1 = std::tanh(drive * (G * u1 + S1)) * invDrive;
        double y2 = std::tanh(drive * (G * y1 + S2)) * invDrive;
        double y3 = std::tanh(drive * (G * y2 + S3)) * invDrive;
        double y4 = std::tanh(drive * (G * y3 + S4)) * invDrive;

        s1 = std::tanh(drive * (2.0 * y1 - s1) * 0.5) * (2.0 * invDrive);
        s2 = std::tanh(drive * (2.0 * y2 - s2) * 0.5) * (2.0 * invDrive);
        s3 = std::tanh(drive * (2.0 * y3 - s3) * 0.5) * (2.0 * invDrive);
        s4 = std::tanh(drive * (2.0 * y4 - s4) * 0.5) * (2.0 * invDrive);

        out[i] = static_cast<float>(y4);
    }

    unit->m_s1 = s1;
    unit->m_s2 = s2;
    unit->m_s3 = s3;
    unit->m_s4 = s4;
}

} // namespace fs
