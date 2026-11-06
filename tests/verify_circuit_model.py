#!/usr/bin/env python3
"""
verify_circuit_model.py: Verification script for MS20Circuit (Transistor / Circuit Model)
Simulates the 2x2 nonlinear MNA state-space system for the Korg-35 circuit with:
- Reverse-saturation BJT variable resistance phi(V) (asymmetric even harmonics)
- Forward-amplifier diode limiter f(V) (odd harmonics)
- Mutual RC stage loading (damping 3 - K)
"""

import numpy as np

def phi_bjt(v, drive, alpha=0.25):
    """
    Reverse-saturation BJT variable resistance function (Stinchcombe Section 3.1).
    Normalized such that phi'(0) = 1.
    Asymmetric saturation: sat+ = 1/alpha, sat- = -1/(1-alpha).
    """
    nu = drive * v
    # Numerically stable evaluation
    pos = nu >= 0
    exp_neg = np.exp(-np.abs(nu))
    
    # For nu >= 0: (1 - e^-nu) / (alpha + (1-alpha)e^-nu)
    # For nu < 0:  (e^nu - 1) / (alpha e^nu + 1 - alpha) = (1 - e^-|nu|) / (-1 * [alpha + (1-alpha)e^|nu|])
    # Using exp_neg = exp(-|nu|):
    val = np.empty_like(nu, dtype=np.float64)
    prime = np.empty_like(nu, dtype=np.float64)
    
    # nu >= 0
    den_pos = alpha + (1.0 - alpha) * exp_neg
    val_pos = (1.0 - exp_neg) / den_pos
    prime_pos = exp_neg / (den_pos * den_pos)
    
    # nu < 0: multiply by exp(nu)
    den_neg = alpha * exp_neg + (1.0 - alpha)
    val_neg = (exp_neg - 1.0) / den_neg
    prime_neg = exp_neg / (den_neg * den_neg)
    
    val = np.where(pos, val_pos, val_neg) / drive
    prime = np.where(pos, prime_pos, prime_neg)
    return val, prime

def f_diode(v, drive=1.0):
    """Forward-amplifier antiparallel diode limiter."""
    arg = drive * v
    arg2 = arg * arg
    d = np.sqrt(1.0 + arg2)
    val = (arg / d) / drive
    prime = 1.0 / (d * (1.0 + arg2))
    return val, prime

def simulate_ms20_circuit(x, fs, fc, res, drive_bjt=1.0, drive_diode=1.0, mode=0, k_max=4.0):
    """
    Simulates MS20Circuit across input array x.
    mode: 0 = Low-Pass, 1 = Authentic MS-20 High-Pass (lifted C2).
    """
    N = len(x)
    y = np.zeros(N, dtype=np.float64)
    
    K = res * k_max
    g = np.tan(np.pi * fc / fs)
    
    s1 = 0.0
    s2 = 0.0
    
    v1 = 0.0
    v2 = 0.0
    
    for n in range(N):
        xn = x[n]
        if mode == 0:
            vin1 = xn
            vref = 0.0
        else:
            vin1 = 0.0
            vref = xn
            
        # 3 Newton-Raphson iterations to solve the 2x2 system
        for _ in range(4):
            u1 = vin1 - v1
            u2 = v1 - v2
            
            phi1, dphi1 = phi_bjt(np.array([u1]), drive_bjt)
            phi2, dphi2 = phi_bjt(np.array([u2]), drive_bjt)
            fv2, dfv2 = f_diode(v2, drive_diode)
            
            # Residuals
            F1 = v1 + v2 - vref - K * fv2 - g * phi1[0] - (s1 + s2)
            F2 = v2 - vref - g * phi2[0] - s2
            
            # Jacobian entries
            j11 = 1.0 + g * dphi1[0]
            j12 = 1.0 - K * dfv2
            j21 = -g * dphi2[0]
            j22 = 1.0 + g * dphi2[0]
            
            det = j11 * j22 - j12 * j21
            inv_det = 1.0 / det
            
            # Delta = - J^-1 * F
            dv1 = -(j22 * F1 - j12 * F2) * inv_det
            dv2 = -(-j21 * F1 + j11 * F2) * inv_det
            
            v1 += dv1
            v2 += dv2
            
        fv2_final, _ = f_diode(v2, drive_diode)
        
        # State updates
        vc2 = v2 - vref
        vc1 = v1 - K * fv2_final
        
        u1_final = vin1 - v1
        u2_final = v1 - v2
        phi1_f, _ = phi_bjt(np.array([u1_final]), drive_bjt)
        phi2_f, _ = phi_bjt(np.array([u2_final]), drive_bjt)
        
        # Output: forward amplifier output
        y[n] = fv2_final
        
        # Update capacitor states: s[n] = 2*v[n] - s[n-1]
        s1 = 2.0 * vc1 - s1
        s2 = 2.0 * vc2 - s2
        
    return y

def test_circuit_model():
    fs = 48000.0
    print("=== Testing MS20Circuit Python Prototype ===")
    
    # 1. Small signal linearity test against linear target
    t = np.arange(4800) / fs
    src_small = 1e-4 * np.sin(2 * np.pi * 20 * t) # 20 Hz deep in passband
    y_small = simulate_ms20_circuit(src_small, fs, 1000.0, 0.25, drive_bjt=1.0, drive_diode=1.0, mode=0, k_max=2.95)
    gain_small = np.max(y_small[2400:]) / 1e-4
    print(f"Small-Signal 20 Hz Passband Gain: {gain_small:.6f} (expected ~1.000)")
    assert abs(gain_small - 1.0) < 0.01, f"Small signal linearity failed: {gain_small}"
    
    # 2. Asymmetric Even-Harmonic Generation Test
    # Feed 200 Hz sine wave under hot drive and inspect FFT harmonics
    src_hot = 2.0 * np.sin(2 * np.pi * 200 * t)
    y_hot = simulate_ms20_circuit(src_hot, fs, 2000.0, 0.2, drive_bjt=4.0, drive_diode=1.0, mode=0)
    
    fft_hot = np.abs(np.fft.rfft(y_hot[2400:] * np.hanning(2400)))
    freqs = np.fft.rfftfreq(2400, 1.0 / fs)
    
    f1_idx = np.argmin(np.abs(freqs - 200.0))
    f2_idx = np.argmin(np.abs(freqs - 400.0)) # Second harmonic (even)
    f3_idx = np.argmin(np.abs(freqs - 600.0)) # Third harmonic (odd)
    
    amp_f1 = fft_hot[f1_idx]
    amp_f2 = fft_hot[f2_idx]
    amp_f3 = fft_hot[f3_idx]
    
    ratio_f2 = amp_f2 / amp_f1
    ratio_f3 = amp_f3 / amp_f1
    
    print(f"Harmonic Analysis under Hot Drive:")
    print(f"  Fundamental (200 Hz): {amp_f1:.2f}")
    print(f"  Second Harmonic (400 Hz, EVEN): {amp_f2:.2f} ({ratio_f2*100:.2f}%)")
    print(f"  Third Harmonic (600 Hz, ODD):   {amp_f3:.2f} ({ratio_f3*100:.2f}%)")
    assert ratio_f2 > 0.01, f"Expected significant 2nd harmonic (>1%), got {ratio_f2*100:.2f}%"
    print("PASS: MS20Circuit successfully generates authentic BJT 2nd harmonic distortion!")
    
    # 3. High-Pass 6 dB/octave Asymptotic Slope Test
    for f_low in [25.0, 50.0]:
        src_hp1 = 1e-3 * np.sin(2 * np.pi * f_low * t)
        src_hp2 = 1e-3 * np.sin(2 * np.pi * (2 * f_low) * t)
        y1 = simulate_ms20_circuit(src_hp1, fs, 2000.0, 0.1, drive_bjt=1.0, drive_diode=1.0, mode=1, k_max=2.95)
        y2 = simulate_ms20_circuit(src_hp2, fs, 2000.0, 0.1, drive_bjt=1.0, drive_diode=1.0, mode=1, k_max=2.95)
        g1 = np.max(y1[2400:])
        g2 = np.max(y2[2400:])
        slope = 20.0 * np.log10(g2 / g1)
        print(f"HP Slope {f_low}->{2*f_low} Hz: {slope:.2f} dB/oct (expected ~ +6.0 dB/oct)")
        assert abs(slope - 6.0) < 0.2, f"HP slope error: {slope}"
    print("PASS: Authentic 6 dB/octave HP slope verified on MS20Circuit!")
    
    # 4. Limit-cycle Self-Oscillation Test
    kick = np.zeros(9600)
    kick[0] = 0.01 # 1-sample kick
    y_osc = simulate_ms20_circuit(kick, fs, 1000.0, 0.9, drive_bjt=1.5, drive_diode=1.0, mode=0, k_max=4.0)
    rms_osc = np.sqrt(np.mean(y_osc[4800:]**2))
    print(f"Autonomous Self-Oscillation Limit Cycle RMS: {rms_osc:.4f}")
    assert 0.2 < rms_osc < 0.9, f"Unexpected self-oscillation RMS: {rms_osc}"
    print("PASS: MS20Circuit enters stable, bounded self-oscillation limit cycle!")

if __name__ == '__main__':
    test_circuit_model()
