#include "Polivoks.hpp"
#include <cmath>
#include <algorithm>

namespace fs {

static constexpr double kPi = 3.14159265358979323846;

static inline double clamp_d(double val, double minVal, double maxVal) {
    return std::max(minVal, std::min(maxVal, val));
}

// Compute bilinear prewarped integrator coefficient g
static inline double calc_g(double freq, double sampleRate) {
    double fc = clamp_d(freq, 10.0, sampleRate * 0.49);
    return std::tan(kPi * fc / sampleRate);
}

// Damping coefficient r from resonance parameter
// In linear mode (drive == 0): res in [0, 1] -> r in [2.0, 0.02] (strictly stable)
// In nonlinear mode (drive > 0): res in [0, 1.2] -> r in [2.0, -0.1] (limit-cycle self-oscillation at res >= 1.0)
static inline double calc_r(double res, double drive) {
    if (drive < 1e-4) {
        double r_clamped = clamp_d(res, 0.0, 1.0);
        return 2.0 * (1.0 - 0.99 * r_clamped);
    } else {
        double r_clamped = clamp_d(res, 0.0, 1.2);
        double r_val = 2.0 * (1.0 - r_clamped);
        return std::max(-0.1, r_val);
    }
}

// K140UD12 differential input stage transconductance saturation
// Slew rate is governed by charging current I_tail * tanh(Vin / (2*Vt))
static inline double f_sat(double x, double alpha) {
    if (alpha < 1e-6) {
        return x;
    }
    return std::tanh(alpha * x) / alpha;
}

// Derivative of f_sat with respect to x: sech^2(alpha * x) in (0, 1]
static inline double df_sat(double x, double alpha) {
    if (alpha < 1e-6) {
        return 1.0;
    }
    double t = std::tanh(alpha * x);
    return 1.0 - t * t;
}

// K140UD12 op-amp output stage rail soft-saturation (~ +/-1.5 V normalized)
static inline double soft_rail(double x) {
    constexpr double rail = 1.5;
    constexpr double inv_rail = 1.0 / rail;
    return rail * std::tanh(x * inv_rail);
}

void Polivoks_Ctor(Polivoks* unit) {
    unit->m_freq = IN0(1);
    unit->m_res = IN0(2);
    unit->m_mode = static_cast<int>(IN0(3));
    unit->m_drive = IN0(4);

    unit->m_s1 = 0.0;
    unit->m_s2 = 0.0;

    bool isAudioRateFreq = (INRATE(1) == calc_FullRate);

    if (unit->m_mode == 1) {
        // Band-Pass mode
        if (isAudioRateFreq) {
            SETCALC(Polivoks_next_bp_a);
        } else {
            SETCALC(Polivoks_next_bp_k);
        }
    } else {
        // Low-Pass mode (default)
        if (isAudioRateFreq) {
            SETCALC(Polivoks_next_lp_a);
        } else {
            SETCALC(Polivoks_next_lp_k);
        }
    }

    // Run first sample
    (unit->mCalcFunc)(unit, 1);
}

// Low-Pass: Control-rate frequency & resonance
void Polivoks_next_lp_k(Polivoks* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);

    double freq = IN0(1);
    double res = IN0(2);
    double drive = clamp_d(IN0(4), 0.0, 20.0);
    double sampleRate = SAMPLERATE;

    double g = calc_g(freq, sampleRate);
    double r = calc_r(res, drive);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    if (drive < 1e-4) {
        // Linear mode
        double denom = 1.0 / (1.0 + r * g + g * g);
        for (int i = 0; i < inNumSamples; ++i) {
            double v_in = in[i];
            double v_sum = (v_in - (r + g) * s1 - s2) * denom;
            double v_bp = g * v_sum + s1;
            double v_lp = g * v_bp + s2;

            s1 = 2.0 * v_bp - s1;
            s2 = 2.0 * v_lp - s2;
            zapgremlins(s1);
            zapgremlins(s2);

            out[i] = static_cast<float>(v_lp);
        }
    } else {
        // Nonlinear mode: Newton-Raphson solver for op-amp saturation inside integrators
        double denom_init = 1.0 / (1.0 + std::max(r, 0.01) * g + g * g);
        for (int i = 0; i < inNumSamples; ++i) {
            double v_in = in[i];
            double v_in_drive = v_in * drive;

            // Warm start from linear predictor
            double x = (v_in_drive - (r + g) * s1 - s2) * denom_init;

            // Newton-Raphson iteration (max 3 iterations)
            for (int it = 0; it < 3; ++it) {
                double f_x = f_sat(x, drive);
                double u = g * f_x + s1;
                double f_u = f_sat(u, drive);

                double F = x + r * g * f_x + g * f_u + r * s1 + s2 - v_in_drive;
                double df_x = df_sat(x, drive);
                double df_u = df_sat(u, drive);
                double dF = 1.0 + g * df_x * (r + g * df_u);

                double dx = F / dF;
                x -= dx;
                if (std::abs(dx) < 1e-7) {
                    break;
                }
            }

            double v_bp = soft_rail(g * f_sat(x, drive) + s1);
            double v_lp = soft_rail(g * f_sat(v_bp, drive) + s2);

            s1 = 2.0 * v_bp - s1;
            s2 = 2.0 * v_lp - s2;
            zapgremlins(s1);
            zapgremlins(s2);

            out[i] = static_cast<float>(v_lp);
        }
    }

    unit->m_s1 = s1;
    unit->m_s2 = s2;
}

// Band-Pass: Control-rate frequency & resonance
void Polivoks_next_bp_k(Polivoks* unit, int inNumSamples) {
    const float* in = IN(0);
    float* out = OUT(0);

    double freq = IN0(1);
    double res = IN0(2);
    double drive = clamp_d(IN0(4), 0.0, 20.0);
    double sampleRate = SAMPLERATE;

    double g = calc_g(freq, sampleRate);
    double r = calc_r(res, drive);

    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    if (drive < 1e-4) {
        // Linear mode
        double denom = 1.0 / (1.0 + r * g + g * g);
        for (int i = 0; i < inNumSamples; ++i) {
            double v_in = in[i];
            double v_sum = (v_in - (r + g) * s1 - s2) * denom;
            double v_bp = g * v_sum + s1;
            double v_lp = g * v_bp + s2;

            s1 = 2.0 * v_bp - s1;
            s2 = 2.0 * v_lp - s2;
            zapgremlins(s1);
            zapgremlins(s2);

            out[i] = static_cast<float>(v_bp);
        }
    } else {
        // Nonlinear mode: Newton-Raphson solver
        double denom_init = 1.0 / (1.0 + std::max(r, 0.01) * g + g * g);
        for (int i = 0; i < inNumSamples; ++i) {
            double v_in = in[i];
            double v_in_drive = v_in * drive;

            double x = (v_in_drive - (r + g) * s1 - s2) * denom_init;

            for (int it = 0; it < 3; ++it) {
                double f_x = f_sat(x, drive);
                double u = g * f_x + s1;
                double f_u = f_sat(u, drive);

                double F = x + r * g * f_x + g * f_u + r * s1 + s2 - v_in_drive;
                double df_x = df_sat(x, drive);
                double df_u = df_sat(u, drive);
                double dF = 1.0 + g * df_x * (r + g * df_u);

                double dx = F / dF;
                x -= dx;
                if (std::abs(dx) < 1e-7) {
                    break;
                }
            }

            double v_bp = soft_rail(g * f_sat(x, drive) + s1);
            double v_lp = soft_rail(g * f_sat(v_bp, drive) + s2);

            s1 = 2.0 * v_bp - s1;
            s2 = 2.0 * v_lp - s2;
            zapgremlins(s1);
            zapgremlins(s2);

            out[i] = static_cast<float>(v_bp);
        }
    }

    unit->m_s1 = s1;
    unit->m_s2 = s2;
}

// Low-Pass: Audio-rate frequency
void Polivoks_next_lp_a(Polivoks* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* freqIn = IN(1);
    float* out = OUT(0);

    double res = IN0(2);
    double drive = clamp_d(IN0(4), 0.0, 20.0);
    double sampleRate = SAMPLERATE;

    double r = calc_r(res, drive);
    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    if (drive < 1e-4) {
        for (int i = 0; i < inNumSamples; ++i) {
            double g = calc_g(freqIn[i], sampleRate);
            double denom = 1.0 / (1.0 + r * g + g * g);
            double v_in = in[i];

            double v_sum = (v_in - (r + g) * s1 - s2) * denom;
            double v_bp = g * v_sum + s1;
            double v_lp = g * v_bp + s2;

            s1 = 2.0 * v_bp - s1;
            s2 = 2.0 * v_lp - s2;
            zapgremlins(s1);
            zapgremlins(s2);

            out[i] = static_cast<float>(v_lp);
        }
    } else {
        for (int i = 0; i < inNumSamples; ++i) {
            double g = calc_g(freqIn[i], sampleRate);
            double denom_init = 1.0 / (1.0 + std::max(r, 0.01) * g + g * g);
            double v_in = in[i];
            double v_in_drive = v_in * drive;

            double x = (v_in_drive - (r + g) * s1 - s2) * denom_init;

            for (int it = 0; it < 3; ++it) {
                double f_x = f_sat(x, drive);
                double u = g * f_x + s1;
                double f_u = f_sat(u, drive);

                double F = x + r * g * f_x + g * f_u + r * s1 + s2 - v_in_drive;
                double df_x = df_sat(x, drive);
                double df_u = df_sat(u, drive);
                double dF = 1.0 + g * df_x * (r + g * df_u);

                double dx = F / dF;
                x -= dx;
                if (std::abs(dx) < 1e-7) {
                    break;
                }
            }

            double v_bp = soft_rail(g * f_sat(x, drive) + s1);
            double v_lp = soft_rail(g * f_sat(v_bp, drive) + s2);

            s1 = 2.0 * v_bp - s1;
            s2 = 2.0 * v_lp - s2;
            zapgremlins(s1);
            zapgremlins(s2);

            out[i] = static_cast<float>(v_lp);
        }
    }

    unit->m_s1 = s1;
    unit->m_s2 = s2;
}

// Band-Pass: Audio-rate frequency
void Polivoks_next_bp_a(Polivoks* unit, int inNumSamples) {
    const float* in = IN(0);
    const float* freqIn = IN(1);
    float* out = OUT(0);

    double res = IN0(2);
    double drive = clamp_d(IN0(4), 0.0, 20.0);
    double sampleRate = SAMPLERATE;

    double r = calc_r(res, drive);
    double s1 = unit->m_s1;
    double s2 = unit->m_s2;

    if (drive < 1e-4) {
        for (int i = 0; i < inNumSamples; ++i) {
            double g = calc_g(freqIn[i], sampleRate);
            double denom = 1.0 / (1.0 + r * g + g * g);
            double v_in = in[i];

            double v_sum = (v_in - (r + g) * s1 - s2) * denom;
            double v_bp = g * v_sum + s1;
            double v_lp = g * v_bp + s2;

            s1 = 2.0 * v_bp - s1;
            s2 = 2.0 * v_lp - s2;
            zapgremlins(s1);
            zapgremlins(s2);

            out[i] = static_cast<float>(v_bp);
        }
    } else {
        for (int i = 0; i < inNumSamples; ++i) {
            double g = calc_g(freqIn[i], sampleRate);
            double denom_init = 1.0 / (1.0 + std::max(r, 0.01) * g + g * g);
            double v_in = in[i];
            double v_in_drive = v_in * drive;

            double x = (v_in_drive - (r + g) * s1 - s2) * denom_init;

            for (int it = 0; it < 3; ++it) {
                double f_x = f_sat(x, drive);
                double u = g * f_x + s1;
                double f_u = f_sat(u, drive);

                double F = x + r * g * f_x + g * f_u + r * s1 + s2 - v_in_drive;
                double df_x = df_sat(x, drive);
                double df_u = df_sat(u, drive);
                double dF = 1.0 + g * df_x * (r + g * df_u);

                double dx = F / dF;
                x -= dx;
                if (std::abs(dx) < 1e-7) {
                    break;
                }
            }

            double v_bp = soft_rail(g * f_sat(x, drive) + s1);
            double v_lp = soft_rail(g * f_sat(v_bp, drive) + s2);

            s1 = 2.0 * v_bp - s1;
            s2 = 2.0 * v_lp - s2;
            zapgremlins(s1);
            zapgremlins(s2);

            out[i] = static_cast<float>(v_bp);
        }
    }

    unit->m_s1 = s1;
    unit->m_s2 = s2;
}

} // namespace fs
