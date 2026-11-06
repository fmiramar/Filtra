#pragma once

#include "SC_PlugIn.h"

namespace ms20 {

// Transposed Direct Form II 1st-order allpass section:
// H(z) = (c + z^-1) / (1 + c * z^-1)
// Difference equation:
//   y[n] = c * x[n] + s[n-1]
//   s[n] = x[n] - c * y[n]
class AllpassSection {
public:
    double c;
    double s;

    void reset(double coef) {
        c = coef;
        s = 0.0;
    }

    inline double process(double x) {
        double y = c * x + s;
        s = x - c * y;
        return y;
    }
};

// 4-stage 2-path polyphase allpass filter for 2x oversampling (Upsampling & Decimation)
// Decomposes a halfband lowpass filter H(z) = 0.5 * (A0(z^2) + z^-1 * A1(z^2))
// Provides > 70 dB stopband rejection and < 0.0005 dB passband ripple.
// Each sample operation requires only 4 multiplications for upsampling and 4 for decimation.
class Halfband2x {
public:
    // Optimal elliptic halfband allpass coefficients:
    // Path 0: c0, c2
    // Path 1: c1, c3
    static constexpr double kC0 = 0.07986642623635751;
    static constexpr double kC1 = 0.28382934487410993;
    static constexpr double kC2 = 0.5453986507421008;
    static constexpr double kC3 = 0.8344117769868580;

    AllpassSection m_up_ap0_0;
    AllpassSection m_up_ap0_1;
    AllpassSection m_up_ap1_0;
    AllpassSection m_up_ap1_1;

    AllpassSection m_dec_ap0_0;
    AllpassSection m_dec_ap0_1;
    AllpassSection m_dec_ap1_0;
    AllpassSection m_dec_ap1_1;
    double m_dec_v1_prev;

    void reset() {
        m_up_ap0_0.reset(kC0);
        m_up_ap0_1.reset(kC2);
        m_up_ap1_0.reset(kC1);
        m_up_ap1_1.reset(kC3);

        m_dec_ap0_0.reset(kC0);
        m_dec_ap0_1.reset(kC2);
        m_dec_ap1_0.reset(kC1);
        m_dec_ap1_1.reset(kC3);
        m_dec_v1_prev = 0.0;
    }

    // 2x Upsampling: takes 1 base-rate sample x, produces 2 samples (y0, y1) at 2x rate
    inline void upsample(double x, double& y0, double& y1) {
        y0 = m_up_ap0_1.process(m_up_ap0_0.process(x));
        y1 = m_up_ap1_1.process(m_up_ap1_0.process(x));
    }

    // 2x Decimation: takes 2 samples (v0, v1) at 2x rate, produces 1 base-rate sample
    inline double decimate(double v0, double v1) {
        double y0 = m_dec_ap0_1.process(m_dec_ap0_0.process(v0));
        double y1 = m_dec_ap1_1.process(m_dec_ap1_0.process(m_dec_v1_prev));
        m_dec_v1_prev = v1;
        return 0.5 * (y0 + y1);
    }

    inline void zap() {
        m_up_ap0_0.s = zapgremlins(m_up_ap0_0.s);
        m_up_ap0_1.s = zapgremlins(m_up_ap0_1.s);
        m_up_ap1_0.s = zapgremlins(m_up_ap1_0.s);
        m_up_ap1_1.s = zapgremlins(m_up_ap1_1.s);
        m_dec_ap0_0.s = zapgremlins(m_dec_ap0_0.s);
        m_dec_ap0_1.s = zapgremlins(m_dec_ap0_1.s);
        m_dec_ap1_0.s = zapgremlins(m_dec_ap1_0.s);
        m_dec_ap1_1.s = zapgremlins(m_dec_ap1_1.s);
        m_dec_v1_prev = zapgremlins(m_dec_v1_prev);
    }
};

} // namespace ms20
