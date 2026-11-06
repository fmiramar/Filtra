#!/usr/bin/env python3
"""
MS20SK Milestone 1 Analytical & Numerical Verification
Verifies:
1. Analog transfer functions H_LP(s) and H_HP(s)
2. Bilinear Transform discretization coefficients
3. High-Pass 6 dB/oct slope and Low-Pass 12 dB/oct slope
4. Sample rate invariance (44.1 kHz, 48 kHz, 96 kHz)
5. Strict stability (poles strictly inside unit circle for res in [0, 1])
"""

import numpy as np

def compute_biquad(fc, res, mode, fs):
    # Clamping
    fc = np.clip(fc, 10.0, 0.49 * fs)
    res = np.clip(res, 0.0, 1.0)
    
    kMax = 2.95
    K = res * kMax
    d1 = 3.0 - K
    
    w = np.tan(np.pi * fc / fs)
    c = 1.0 / w
    c2 = c * c
    
    a0 = c2 + d1 * c + 1.0
    inv_a0 = 1.0 / a0
    
    a1 = 2.0 * (1.0 - c2) * inv_a0
    a2 = (c2 - d1 * c + 1.0) * inv_a0
    
    if mode == 0:
        b0 = inv_a0
        b1 = 2.0 * inv_a0
        b2 = inv_a0
    else:
        b0 = (c2 + 2.0 * c) * inv_a0
        b1 = (-2.0 * c2) * inv_a0
        b2 = (c2 - 2.0 * c) * inv_a0
        
    return (b0, b1, b2, a1, a2)

def eval_h(b0, b1, b2, a1, a2, f, fs):
    w = 2.0 * np.pi * f / fs
    z = np.exp(-1j * w)
    num = b0 + b1 * z + b2 * (z**2)
    den = 1.0 + a1 * z + a2 * (z**2)
    return num / den

def run_tpt_impulse(fc, res, mode, fs, N=1024):
    kMax = 2.95
    K = np.clip(res, 0.0, 1.0) * kMax
    g = np.tan(np.pi * np.clip(fc, 10.0, 0.49 * fs) / fs)
    det = g * g + (3.0 - K) * g + 1.0
    inv_det = 1.0 / det

    m00 = (1.0 - g * (K - 1.0)) * inv_det
    m01 = (g * (2.0 * K - 1.0)) * inv_det
    m10 = (-g) * inv_det
    m11 = (1.0 + 2.0 * g) * inv_det

    if mode == 0:
        b00 = -g
        b10 = 0.0
    else:
        b00 = g * (2.0 * K - 1.0)
        b10 = g * (K - 1.0)

    x = np.zeros(N)
    x[0] = 1.0
    y = np.zeros(N)
    s1, s2 = 0.0, 0.0

    if mode == 0:
        for i in range(N):
            xn = x[i]
            r1 = b00 * xn + s1
            r2 = s2
            vc1 = m00 * r1 + m01 * r2
            vc2 = m10 * r1 + m11 * r2
            y[i] = vc2
            s1 = 2.0 * vc1 - s1
            s2 = 2.0 * vc2 - s2
    else:
        for i in range(N):
            xn = x[i]
            r1 = b00 * xn + s1
            r2 = b10 * xn + s2
            vc1 = m00 * r1 + m01 * r2
            vc2 = m10 * r1 + m11 * r2
            y[i] = vc2 + xn
            s1 = 2.0 * vc1 - s1
            s2 = 2.0 * vc2 - s2

    return y

def run_biquad_impulse(fc, res, mode, fs, N=1024):
    b0, b1, b2, a1, a2 = compute_biquad(fc, res, mode, fs)
    x = np.zeros(N)
    x[0] = 1.0
    y = np.zeros(N)
    s1, s2 = 0.0, 0.0
    for i in range(N):
        xn = x[i]
        yn = b0 * xn + s1
        s1 = b1 * xn - a1 * yn + s2
        s2 = b2 * xn - a2 * yn
        y[i] = yn
    return y

def test_numerical():
    print("=== MS20SK Milestone 1 Analytical & Numerical Tests ===")
    
    # 1. Pole stability check across sample rates and full resonance sweep
    for fs in [44100.0, 48000.0, 96000.0]:
        for res in [0.0, 0.25, 0.5, 0.75, 0.9, 0.99, 1.0]:
            for fc in [50.0, 1000.0, 10000.0]:
                b0, b1, b2, a1, a2 = compute_biquad(fc, res, 0, fs)
                # Roots of 1 + a1*z^-1 + a2*z^-2 = 0 <=> z^2 + a1*z + a2 = 0
                poles = np.roots([1.0, a1, a2])
                max_pole_r = np.max(np.abs(poles))
                assert max_pole_r < 1.0, f"Unstable pole {max_pole_r} at fs={fs}, fc={fc}, res={res}"
    print("[PASS] All poles are strictly inside unit circle (|z| < 1) for all tested fs, fc, and res in [0, 1].")
    
    # 2. HP slope check (asymptotic 6 dB/octave)
    for fs in [44100.0, 48000.0, 96000.0]:
        fc = 4000.0
        coeffs_hp = compute_biquad(fc, 0.0, 1, fs)
        h_25 = eval_h(*coeffs_hp, 25.0, fs)
        h_50 = eval_h(*coeffs_hp, 50.0, fs)
        h_100 = eval_h(*coeffs_hp, 100.0, fs)
        slope_1 = 20.0 * np.log10(np.abs(h_50) / np.abs(h_25))
        slope_2 = 20.0 * np.log10(np.abs(h_100) / np.abs(h_50))
        print(f"[HP fs={int(fs)}] 25->50Hz: {slope_1:.3f} dB/oct | 50->100Hz: {slope_2:.3f} dB/oct (expected ~6.0 dB/oct)")
        assert 5.90 <= slope_1 <= 6.05, f"HP slope error: {slope_1}"
        assert 5.90 <= slope_2 <= 6.05, f"HP slope error: {slope_2}"
        
    # 3. LP slope check (asymptotic 12 dB/octave)
    for fs in [44100.0, 48000.0, 96000.0]:
        fc = 200.0
        coeffs_lp = compute_biquad(fc, 0.0, 0, fs)
        h_2000 = eval_h(*coeffs_lp, 2000.0, fs)
        h_4000 = eval_h(*coeffs_lp, 4000.0, fs)
        slope = 20.0 * np.log10(np.abs(h_4000) / np.abs(h_2000))
        print(f"[LP fs={int(fs)}] 2000->4000Hz: {slope:.3f} dB/oct (expected ~ -12.0 dB/oct)")
        assert -12.5 <= slope <= -11.8, f"LP slope error: {slope}"
        
    # 4. DC & Nyquist gains
    coeffs_lp = compute_biquad(1000.0, 0.5, 0, 48000.0)
    dc_lp = eval_h(*coeffs_lp, 0.0, 48000.0)
    print(f"LP DC Gain: {np.abs(dc_lp):.6f} (exact 1.000000 = 0 dB)")
    assert np.isclose(np.abs(dc_lp), 1.0)
    
    coeffs_hp = compute_biquad(1000.0, 0.5, 1, 48000.0)
    dc_hp = eval_h(*coeffs_hp, 0.0, 48000.0)
    nyq_hp = eval_h(*coeffs_hp, 24000.0, 48000.0)
    print(f"HP DC Gain: {np.abs(dc_hp):.6e} (exact 0.000000 = -inf dB)")
    print(f"HP Nyquist Gain: {np.abs(nyq_hp):.6f} (exact 1.000000 = 0 dB)")
    assert np.isclose(np.abs(dc_hp), 0.0)
    assert np.isclose(np.abs(nyq_hp), 1.0)
    
    # 5. Direct A/B equivalence (MS20SK vs MS20TPT) across sample rates
    for fs in [44100.0, 48000.0, 96000.0]:
        for mode in [0, 1]:
            for res in [0.0, 0.5, 0.9]:
                y_sk = run_biquad_impulse(1500.0, res, mode, fs)
                y_tpt = run_tpt_impulse(1500.0, res, mode, fs)
                diff = np.max(np.abs(y_sk - y_tpt))
                mode_str = "LP" if mode == 0 else "HP"
                print(f"[A/B fs={int(fs)} {mode_str} res={res:.1f}] Max diff: {diff:.2e}")
                assert diff < 1e-12, f"Equivalence failure at fs={fs}, mode={mode}: {diff}"

    # 6. Milestone 3 Diode Limiter vs Tanh Approximation & Test Matrix
    print("\n--- Milestone 3 Diode vs Tanh Comparison & 3x3x3 Test Matrix ---")
    def run_diode_sim(sig, fc, res, drive, mode, fs, use_tanh=False):
        g = np.tan(np.pi * np.clip(fc, 10.0, 0.49 * fs) / fs)
        K = np.clip(res, 0.0, 1.0) * 4.0
        c_lin = 1.0 + 3.0 * g + g * g
        dK_lin = min(K, 2.9)
        inv_lin_den = 1.0 / (g * g + (3.0 - dK_lin) * g + 1.0)
        inv_1p2g = 1.0 / (1.0 + 2.0 * g)
        inv_drive = 1.0 / drive

        y = np.zeros(len(sig))
        s1, s2 = 0.0, 0.0

        for i, xn in enumerate(sig):
            if mode == 0:
                p = (1.0 + 2.0 * g) * s2 - g * s1 + g * g * xn
                v = p * inv_lin_den
                for _ in range(3):
                    arg = drive * v
                    if use_tanh:
                        th = np.tanh(arg)
                        f_val = th * inv_drive
                        f_prime = 1.0 - th * th
                    else:
                        arg2 = arg * arg
                        d = np.sqrt(1.0 + arg2)
                        f_val = (arg / d) * inv_drive
                        f_prime = 1.0 / (d * (1.0 + arg2))
                    F = c_lin * v - g * K * f_val - p
                    dF = c_lin - g * K * f_prime
                    v -= F / dF

                arg = drive * v
                if use_tanh:
                    f_val = np.tanh(arg) * inv_drive
                else:
                    f_val = (arg / np.sqrt(1.0 + arg * arg)) * inv_drive
                vc2 = v
                vc1 = (2.0 * g * K * f_val - g * vc2 - g * xn + s1) * inv_1p2g
                y[i] = f_val
                s1 = 2.0 * vc1 - s1
                s2 = 2.0 * vc2 - s2
            else:
                p_u = (1.0 + 2.0 * g) * (s2 + xn) - g * s1
                u = p_u * inv_lin_den
                for _ in range(3):
                    arg = drive * u
                    if use_tanh:
                        th = np.tanh(arg)
                        f_val = th * inv_drive
                        f_prime = 1.0 - th * th
                    else:
                        arg2 = arg * arg
                        d = np.sqrt(1.0 + arg2)
                        f_val = (arg / d) * inv_drive
                        f_prime = 1.0 / (d * (1.0 + arg2))
                    F = c_lin * u - g * K * f_val - p_u
                    dF = c_lin - g * K * f_prime
                    u -= F / dF

                arg = drive * u
                if use_tanh:
                    f_val = np.tanh(arg) * inv_drive
                else:
                    f_val = (arg / np.sqrt(1.0 + arg * arg)) * inv_drive
                vc2 = u - xn
                vc1 = (2.0 * g * K * f_val - g * u + s1) * inv_1p2g
                y[i] = f_val
                s1 = 2.0 * vc1 - s1
                s2 = 2.0 * vc2 - s2

        return y

    # Test Matrix: 3 levels (quiet 0.05, nominal 0.3, hot 1.5) x 3 resonances (0.1, 0.5, 0.9) x 3 freqs (200, 1000, 3000 Hz)
    print("Level     | Res   | Fin (Hz) | RMS Diode | RMS Tanh  | Max Peak")
    print("---------------------------------------------------------------")
    for amp, l_name in [(0.05, 'quiet  '), (0.3, 'nominal'), (1.5, 'hot    ')]:
        for res, r_name in [(0.1, 'low '), (0.5, 'mid '), (0.9, 'high')]:
            for fin in [200.0, 1000.0, 3000.0]:
                t = np.arange(4800) / 48000.0
                sig = amp * np.sin(2 * np.pi * fin * t)
                y_dio = run_diode_sim(sig, 1000.0, res, 1.0, 0, 48000.0, use_tanh=False)
                y_tnh = run_diode_sim(sig, 1000.0, res, 1.0, 0, 48000.0, use_tanh=True)
                rms_dio = np.sqrt(np.mean(y_dio[2400:]**2))
                rms_tnh = np.sqrt(np.mean(y_tnh[2400:]**2))
                peak_dio = np.max(np.abs(y_dio[2400:]))
                print(f"{l_name} | {r_name} | {fin:7.0f}  | {rms_dio:9.4f} | {rms_tnh:9.4f} | {peak_dio:8.4f}")
                # Sanity: output is strictly bounded
                assert peak_dio < 1.2, f"Diode peak exploded: {peak_dio}"

    # Self-oscillation limit cycle across sample rates
    for fs in [44100.0, 48000.0, 96000.0]:
        sig_kick = np.zeros(int(fs * 0.1))
        sig_kick[0] = 0.01
        y_osc = run_diode_sim(sig_kick, 1000.0, 0.95, 1.0, 0, fs)
        tail_osc = y_osc[int(len(y_osc) / 2):]
        rms_osc = np.sqrt(np.mean(tail_osc**2))
        print(f"[Self-Osc fs={int(fs)}] RMS = {rms_osc:.4f} (expected ~0.51)")
        assert 0.40 <= rms_osc <= 0.60, f"Self-oscillation RMS unexpected: {rms_osc}"

    # 7. Milestone 4 OTA Filter (KLM-307) Analytical Verification
    print("\n--- Milestone 4 OTA Filter (KLM-307) Analytical Verification ---")
    def run_ota_sim(sig, fc, res, drive, mode, fs):
        g = np.tan(np.pi * np.clip(fc, 10.0, 0.49 * fs) / fs)
        K = np.clip(res, 0.0, 1.0) * 2.5 # Critical oscillation at K=2.0
        c_lin = (1.0 + g)**2
        dK_lin = min(K, 1.95)
        inv_lin_den = 1.0 / (g * g + (2.0 - dK_lin) * g + 1.0)
        one_plus_g = 1.0 + g
        inv_drive = 1.0 / drive

        y = np.zeros(len(sig))
        s1, s2 = 0.0, 0.0

        for i, xn in enumerate(sig):
            if mode == 0:
                p = g * xn + s1 - one_plus_g * s2
                vfb = p * inv_lin_den
                for _ in range(3):
                    arg = drive * vfb
                    arg2 = arg * arg
                    d = np.sqrt(1.0 + arg2)
                    f_val = (arg / d) * inv_drive
                    f_prime = 1.0 / (d * (1.0 + arg2))
                    F = c_lin * vfb - g * K * f_val - p
                    dF = c_lin - g * K * f_prime
                    vfb -= F / dF

                v2 = one_plus_g * vfb + s2
                vo = g * vfb + s2
                y[i] = vo
                s1 = 2.0 * v2 - s1
                s2 = 2.0 * vo - s2
            else:
                p_u = s1 - one_plus_g * (s2 + xn)
                vfb = p_u * inv_lin_den
                for _ in range(3):
                    arg = drive * vfb
                    arg2 = arg * arg
                    d = np.sqrt(1.0 + arg2)
                    f_val = (arg / d) * inv_drive
                    f_prime = 1.0 / (d * (1.0 + arg2))
                    F = c_lin * vfb - g * K * f_val - p_u
                    dF = c_lin - g * K * f_prime
                    vfb -= F / dF

                v2 = one_plus_g * vfb + s2 + xn
                vc2 = g * vfb + s2
                vo = vc2 + xn
                y[i] = vo
                s1 = 2.0 * v2 - s1
                s2 = 2.0 * vc2 - s2

        return y

    for fs in [44100.0, 48000.0, 96000.0]:
        t = np.arange(int(fs * 0.1)) / fs
        # LP slope
        sig_2k = np.sin(2 * np.pi * 2000.0 * t)
        sig_4k = np.sin(2 * np.pi * 4000.0 * t)
        y_2k = run_ota_sim(sig_2k, 500.0, 0.0, 1.0, 0, fs)
        y_4k = run_ota_sim(sig_4k, 500.0, 0.0, 1.0, 0, fs)
        g_2k = np.sqrt(np.mean(y_2k[int(len(y_2k)/2):]**2))
        g_4k = np.sqrt(np.mean(y_4k[int(len(y_4k)/2):]**2))
        slope_lp = 20 * np.log10(g_4k / g_2k)

        # HP slope
        sig_50 = np.sin(2 * np.pi * 50.0 * t)
        sig_100 = np.sin(2 * np.pi * 100.0 * t)
        y_50 = run_ota_sim(sig_50, 2000.0, 0.0, 1.0, 1, fs)
        y_100 = run_ota_sim(sig_100, 2000.0, 0.0, 1.0, 1, fs)
        g_50 = np.sqrt(np.mean(y_50[int(len(y_50)/2):]**2))
        g_100 = np.sqrt(np.mean(y_100[int(len(y_100)/2):]**2))
        slope_hp = 20 * np.log10(g_100 / g_50)

        # Self-oscillation limit cycle
        sig_kick = np.zeros(int(fs * 0.1))
        sig_kick[0] = 0.01
        y_osc = run_ota_sim(sig_kick, 1000.0, 0.95, 1.0, 0, fs)
        tail_osc = y_osc[int(len(y_osc)/2):]
        rms_osc = np.sqrt(np.mean(tail_osc**2))

        print(f"[OTA fs={int(fs)}] LP Slope: {slope_lp:6.2f} dB/oct | HP Slope: {slope_hp:5.2f} dB/oct | Self-Osc RMS: {rms_osc:6.4f}")
        assert -12.5 <= slope_lp <= -11.5
        assert 5.90 <= slope_hp <= 6.10
        assert 0.45 <= rms_osc <= 0.65

    print("\nALL ANALYTICAL TESTS PASSED SUCCESSFULLY!")

if __name__ == '__main__':
    test_numerical()
