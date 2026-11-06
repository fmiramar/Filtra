#!/usr/bin/env python3
"""
generate_comparison_pdf.py: Generates a comprehensive technical report PDF
displaying analytical curves, frequency responses, harmonic distortion profiles,
phase portraits, and time-domain waveforms comparing all models in the MS-20 filter family:
1. MS20SK      - Linear Sallen-Key Biquad Reference (Mutual Loading 3 - K)
2. MS20TPT     - Zero-Delay Topology-Preserving Transform (Physical Capacitor States)
3. MS20Diode   - Early Korg-35 Forward Diode Limiter (Symmetric Odd Harmonics)
4. MS20OTA     - Later KLM-307 Dual OTA Filter (Feedback Diodes, Passband Immunity)
5. MS20Circuit - Discrete Transistor BJT Model (Asymmetric Even Harmonics)
"""

import os
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
import scipy.signal as signal

# Set overall publication plot style
plt.rcParams['font.sans-serif'] = 'Helvetica', 'Arial', 'DejaVu Sans'
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['axes.labelsize'] = 10
plt.rcParams['axes.titlesize'] = 11
plt.rcParams['xtick.labelsize'] = 9
plt.rcParams['ytick.labelsize'] = 9
plt.rcParams['legend.fontsize'] = 8.5
plt.rcParams['figure.titlesize'] = 14

# Color palette for consistent model identity across all plots
COLORS = {
    'SK':      '#1f77b4',  # Blue
    'TPT':     '#2ca02c',  # Green
    'Diode':   '#d62728',  # Red
    'OTA':     '#9467bd',  # Purple
    'Circuit': '#ff7f0e',  # Orange
    'Grid':    '#e0e0e0'
}

# -----------------------------------------------------------------------------
# DSP Helper Functions
# -----------------------------------------------------------------------------

def get_biquad_coeffs(fc, fs, res, mode=0, is_ota=False):
    """
    Returns (b, a) digital filter coefficients via prewarped bilinear transform.
    mode: 0 = Low-Pass, 1 = Authentic MS-20 High-Pass.
    is_ota: False = Korg-35 (loading damping 3 - K), True = OTA (damping 2 - K).
    """
    w = np.tan(np.pi * fc / fs)
    c = 1.0 / w
    c2 = c * c

    if is_ota:
        K = res * 1.95  # Linear range bounded below K = 2.0
        d1 = 2.0 - K
    else:
        K = res * 2.95  # Linear range bounded below K = 3.0
        d1 = 3.0 - K

    a0 = c2 + d1 * c + 1.0
    a1 = 2.0 * (1.0 - c2)
    a2 = c2 - d1 * c + 1.0

    if mode == 0:
        # Low-Pass: N(s) = 1
        b0 = 1.0
        b1 = 2.0
        b2 = 1.0
    else:
        # Authentic MS-20 High-Pass
        if is_ota:
            # N(s) = u^2 + u
            b0 = c2 + c
            b1 = -2.0 * c2
            b2 = c2 - c
        else:
            # N(s) = u^2 + 2u
            b0 = c2 + 2.0 * c
            b1 = -2.0 * c2
            b2 = c2 - 2.0 * c

    b = np.array([b0, b1, b2]) / a0
    a = np.array([a0, a1, a2]) / a0
    return b, a

def simulate_nonlinear_step(x, fs, fc, res, drive, model='Diode', mode=0):
    """
    Simulates time-domain nonlinear response for Diode, OTA, or Circuit.
    """
    N = len(x)
    y = np.zeros(N)
    vc1_hist = np.zeros(N)
    vc2_hist = np.zeros(N)
    
    g = np.tan(np.pi * fc / fs)
    inv_drive = 1.0 / drive

    s1 = 0.0
    s2 = 0.0
    v1 = 0.0
    v2 = 0.0

    if model == 'Diode':
        K = res * 4.0
        c_lin = 1.0 + 3.0 * g + g * g
        dK_lin = min(K, 2.9)
        inv_lin_den = 1.0 / (g * g + (3.0 - dK_lin) * g + 1.0)
        inv_1p2g = 1.0 / (1.0 + 2.0 * g)

        for n in range(N):
            xn = x[n]
            if mode == 0:
                p = (1.0 + 2.0 * g) * s2 - g * s1 + g * g * xn
                v = p * inv_lin_den
                for _ in range(3):
                    arg = drive * v
                    arg2 = arg * arg
                    d = np.sqrt(1.0 + arg2)
                    f_val = (arg / d) * inv_drive
                    f_prime = 1.0 / (d * (1.0 + arg2))
                    F = c_lin * v - g * K * f_val - p
                    dF = c_lin - g * K * f_prime
                    v -= F / dF
                arg = drive * v
                d = np.sqrt(1.0 + arg * arg)
                f_val = (arg / d) * inv_drive
                vc2 = v
                vc1 = (2.0 * g * K * f_val - g * vc2 - g * xn + s1) * inv_1p2g
                out_val = f_val
            else:
                p_u = (1.0 + 2.0 * g) * (s2 + xn) - g * s1
                u = p_u * inv_lin_den
                for _ in range(3):
                    arg = drive * u
                    arg2 = arg * arg
                    d = np.sqrt(1.0 + arg2)
                    f_val = (arg / d) * inv_drive
                    f_prime = 1.0 / (d * (1.0 + arg2))
                    F = c_lin * u - g * K * f_val - p_u
                    dF = c_lin - g * K * f_prime
                    u -= F / dF
                arg = drive * u
                d = np.sqrt(1.0 + arg * arg)
                f_val = (arg / d) * inv_drive
                vc2 = u - xn
                vc1 = (2.0 * g * K * f_val - g * u + s1) * inv_1p2g
                out_val = f_val

            y[n] = out_val
            vc1_hist[n] = vc1
            vc2_hist[n] = vc2
            s1 = 2.0 * vc1 - s1
            s2 = 2.0 * vc2 - s2

    elif model == 'OTA':
        K = res * 2.5
        c_lin = (1.0 + g) * (1.0 + g)
        dK_lin = min(K, 1.95)
        inv_lin_den = 1.0 / (g * g + (2.0 - dK_lin) * g + 1.0)
        one_plus_g = 1.0 + g

        for n in range(N):
            xn = x[n]
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
                v2_val = one_plus_g * vfb + s2
                vo = g * vfb + s2
                out_val = vo
                vc1 = v2_val
                vc2 = vo
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
                v2_val = one_plus_g * vfb + s2 + xn
                vc2 = g * vfb + s2
                vo = vc2 + xn
                out_val = vo
                vc1 = v2_val

            y[n] = out_val
            vc1_hist[n] = vc1
            vc2_hist[n] = vc2
            s1 = 2.0 * vc1 - s1
            s2 = 2.0 * vc2 - s2

    elif model == 'Circuit':
        K = res * 4.0
        alpha = 0.25

        def phi_bjt(v):
            nu = drive * v
            abs_nu = np.abs(nu)
            clipped_nu = min(abs_nu, 40.0)
            exp_neg = np.exp(-clipped_nu)
            if nu >= 0.0:
                den = alpha + (1.0 - alpha) * exp_neg
                val = ((1.0 - exp_neg) / den) * inv_drive
                prime = exp_neg / (den * den)
            else:
                den = alpha * exp_neg + (1.0 - alpha)
                val = ((exp_neg - 1.0) / den) * inv_drive
                prime = exp_neg / (den * den)
            return val, prime

        for n in range(N):
            xn = x[n]
            vin1 = xn if mode == 0 else 0.0
            vref = 0.0 if mode == 0 else xn
            s1_plus_s2 = s1 + s2

            for _ in range(3):
                u1 = vin1 - v1
                u2 = v1 - v2
                phi1, dphi1 = phi_bjt(u1)
                phi2, dphi2 = phi_bjt(u2)
                arg = drive * v2
                arg2 = arg * arg
                d = np.sqrt(1.0 + arg2)
                fv2 = (arg / d) * inv_drive
                dfv2 = 1.0 / (d * (1.0 + arg2))

                F1 = v1 + v2 - vref - K * fv2 - g * phi1 - s1_plus_s2
                F2 = v2 - vref - g * phi2 - s2

                j11 = 1.0 + g * dphi1
                j12 = 1.0 - K * dfv2
                j21 = -g * dphi2
                j22 = 1.0 + g * dphi2

                det = j11 * j22 - j12 * j21
                inv_det = 1.0 / det if abs(det) > 1e-12 else 1.0

                v1 += -(j22 * F1 - j12 * F2) * inv_det
                v2 += -(-j21 * F1 + j11 * F2) * inv_det

            arg = drive * v2
            d = np.sqrt(1.0 + arg * arg)
            fv2_final = (arg / d) * inv_drive

            vc2 = v2 - vref
            vc1 = v1 - K * fv2_final

            y[n] = fv2_final
            vc1_hist[n] = vc1
            vc2_hist[n] = vc2

            s1 = 2.0 * vc1 - s1
            s2 = 2.0 * vc2 - s2

    return y, vc1_hist, vc2_hist

# -----------------------------------------------------------------------------
# Main PDF Generation
# -----------------------------------------------------------------------------

def generate_pdf(output_path="MS20_Filter_Family_Comparison_Curves.pdf"):
    fs = 48000.0
    w_freqs = np.logspace(np.log10(10.0), np.log10(20000.0), 2000)
    w_rad = 2.0 * np.pi * w_freqs / fs

    with PdfPages(output_path) as pdf:

        # =====================================================================
        # PAGE 1: Linear Frequency Responses & Asymptotic Slopes
        # =====================================================================
        fig, axs = plt.subplots(2, 2, figsize=(11, 8.5))
        fig.suptitle("MS-20 Filter Suite — Linear Frequency Responses & Asymptotic Slopes", fontsize=15, y=0.98, weight='bold')

        # 1A: Low-Pass Frequency Response for multiple cutoffs
        cutoffs = [100, 300, 1000, 3000, 8000]
        ax = axs[0, 0]
        for fc in cutoffs:
            b, a = get_biquad_coeffs(fc, fs, res=0.3, mode=0)
            _, h = signal.freqz(b, a, worN=w_rad)
            ax.semilogx(w_freqs, 20 * np.log10(np.abs(h) + 1e-12), label=f"$f_c = {fc}$ Hz", lw=1.8)

        # Plot theoretical -12 dB/oct asymptote reference line
        f_ref = np.array([2000.0, 8000.0])
        mag_ref = -12.0 * np.log2(f_ref / 2000.0) - 10.0
        ax.semilogx(f_ref, mag_ref, 'k--', label="Asymptote: -12 dB/oct", lw=1.5, alpha=0.7)

        ax.set_title("1A. Low-Pass Mode (MS20SK / MS20TPT) Frequency Response")
        ax.set_xlabel("Frequency (Hz)")
        ax.set_ylabel("Magnitude (dB)")
        ax.set_ylim(-60, 10)
        ax.set_xlim(20, 20000)
        ax.grid(True, which="both", ls=":", color=COLORS['Grid'])
        ax.legend(loc="lower left", framealpha=0.9)

        # 1B: Authentic MS-20 High-Pass Response (6 dB/octave slope)
        ax = axs[0, 1]
        for fc in cutoffs:
            b, a = get_biquad_coeffs(fc, fs, res=0.3, mode=1)
            _, h = signal.freqz(b, a, worN=w_rad)
            ax.semilogx(w_freqs, 20 * np.log10(np.abs(h) + 1e-12), label=f"$f_c = {fc}$ Hz", lw=1.8)

        # Plot theoretical +6 dB/oct asymptote reference line
        f_ref_hp = np.array([30.0, 240.0])
        mag_ref_hp = 6.0 * np.log2(f_ref_hp / 30.0) - 35.0
        ax.semilogx(f_ref_hp, mag_ref_hp, 'k--', label="Asymptote: +6 dB/oct", lw=1.5, alpha=0.7)

        ax.set_title("1B. Authentic MS-20 High-Pass Mode (+6 dB/octave Roll-off)")
        ax.set_xlabel("Frequency (Hz)")
        ax.set_ylabel("Magnitude (dB)")
        ax.set_ylim(-60, 10)
        ax.set_xlim(20, 20000)
        ax.grid(True, which="both", ls=":", color=COLORS['Grid'])
        ax.legend(loc="lower right", framealpha=0.9)

        # 1C: Resonance Variation in LP and HP Modes
        ax = axs[1, 0]
        res_values = [0.0, 0.25, 0.5, 0.75, 0.95]
        fc_res = 1000.0
        for r in res_values:
            b, a = get_biquad_coeffs(fc_res, fs, res=r, mode=0)
            _, h = signal.freqz(b, a, worN=w_rad)
            ax.semilogx(w_freqs, 20 * np.log10(np.abs(h) + 1e-12), label=f"res = {r:.2f}", lw=1.8)

        ax.set_title("1C. Resonance Peak Evolution ($f_c = 1000$ Hz, Low-Pass)")
        ax.set_xlabel("Frequency (Hz)")
        ax.set_ylabel("Magnitude (dB)")
        ax.set_ylim(-50, 25)
        ax.set_xlim(100, 10000)
        ax.grid(True, which="both", ls=":", color=COLORS['Grid'])
        ax.legend(loc="upper right", framealpha=0.9)

        # 1D: Authentic MS-20 Serial Dual-Filter Patch (HPF -> LPF)
        ax = axs[1, 1]
        serial_configs = [
            ("Wide Band", 80, 0.3, 5000, 0.3),
            ("Formant Voice", 250, 0.5, 1800, 0.6),
            ("Narrow Peak", 600, 0.6, 900, 0.7),
            ("Sub Bass Pass", 40, 0.2, 400, 0.4)
        ]
        for name, f_hp, r_hp, f_lp, r_lp in serial_configs:
            b_hp, a_hp = get_biquad_coeffs(f_hp, fs, res=r_hp, mode=1)
            b_lp, a_lp = get_biquad_coeffs(f_lp, fs, res=r_lp, mode=0)
            _, h_hp = signal.freqz(b_hp, a_hp, worN=w_rad)
            _, h_lp = signal.freqz(b_lp, a_lp, worN=w_rad)
            h_serial = h_hp * h_lp
            ax.semilogx(w_freqs, 20 * np.log10(np.abs(h_serial) + 1e-12), label=f"{name} ({f_hp}H -> {f_lp}L)", lw=2.0)

        ax.set_title("1D. Authentic MS-20 Serial Chain: HPF (6 dB/oct) $\\to$ LPF (12 dB/oct)")
        ax.set_xlabel("Frequency (Hz)")
        ax.set_ylabel("Magnitude (dB)")
        ax.set_ylim(-60, 15)
        ax.set_xlim(20, 20000)
        ax.grid(True, which="both", ls=":", color=COLORS['Grid'])
        ax.legend(loc="lower center", framealpha=0.9)

        plt.tight_layout(rect=[0, 0, 1, 0.96])
        fig.savefig("docs/page1_linear_frequency_response.png", dpi=200)
        pdf.savefig(fig)
        plt.close(fig)

        # =====================================================================
        # PAGE 2: Circuit Architecture: Korg-35 vs KLM-307 OTA
        # =====================================================================
        fig, axs = plt.subplots(2, 2, figsize=(11, 8.5))
        fig.suptitle("MS-20 Filter Suite — Circuit Topology & Damping: Korg-35 vs KLM-307 OTA", fontsize=15, y=0.98, weight='bold')

        # 2A: Damping Term vs Feedback Gain K
        ax = axs[0, 0]
        K_korg = np.linspace(0.0, 3.2, 200)
        K_ota  = np.linspace(0.0, 2.2, 200)
        d_korg = 3.0 - K_korg
        d_ota  = 2.0 - K_ota

        ax.plot(K_korg, d_korg, color=COLORS['Diode'], lw=2.2, label="Korg-35 (Loaded): $d(K) = 3 - K$ (Osc @ $K=3.0$)")
        ax.plot(K_ota, d_ota, color=COLORS['OTA'], lw=2.2, label="KLM-307 OTA (Buffered): $d(K) = 2 - K$ (Osc @ $K=2.0$)")
        ax.axhline(0, color='black', lw=1.2, ls="--")
        ax.axvline(3.0, color=COLORS['Diode'], ls=":", alpha=0.7)
        ax.axvline(2.0, color=COLORS['OTA'], ls=":", alpha=0.7)

        ax.set_title("2A. Damping Factor & Critical Self-Oscillation Threshold")
        ax.set_xlabel("Feedback Parameter $K$")
        ax.set_ylabel("Linear Damping Factor $d$")
        ax.set_ylim(-0.5, 3.5)
        ax.set_xlim(0, 3.2)
        ax.grid(True, ls=":", color=COLORS['Grid'])
        ax.legend(loc="upper right", framealpha=0.9)

        # 2B: Phase Response Comparison
        ax = axs[0, 1]
        fc_phase = 1000.0
        # Korg-35 LP & HP
        b_lp, a_lp = get_biquad_coeffs(fc_phase, fs, res=0.4, mode=0, is_ota=False)
        b_hp, a_hp = get_biquad_coeffs(fc_phase, fs, res=0.4, mode=1, is_ota=False)
        _, h_lp = signal.freqz(b_lp, a_lp, worN=w_rad)
        _, h_hp = signal.freqz(b_hp, a_hp, worN=w_rad)

        phase_lp = np.unwrap(np.angle(h_lp)) * 180.0 / np.pi
        phase_hp = np.unwrap(np.angle(h_hp)) * 180.0 / np.pi

        ax.semilogx(w_freqs, phase_lp, color=COLORS['SK'], lw=2.0, label="Low-Pass Phase ($0^\\circ \\to -180^\\circ$)")
        ax.semilogx(w_freqs, phase_hp, color=COLORS['Diode'], lw=2.0, label="Authentic HP Phase ($+90^\\circ \\to 0^\\circ$)")
        ax.axhline(90, color='gray', ls=":", alpha=0.6)
        ax.axhline(0, color='gray', ls="--", alpha=0.6)
        ax.axhline(-90, color='gray', ls=":", alpha=0.6)
        ax.axhline(-180, color='gray', ls=":", alpha=0.6)

        ax.set_title("2B. Phase Response ($f_c = 1000$ Hz, Single DC Zero on HP)")
        ax.set_xlabel("Frequency (Hz)")
        ax.set_ylabel("Phase (Degrees)")
        ax.set_ylim(-200, 120)
        ax.set_xlim(20, 20000)
        ax.grid(True, which="both", ls=":", color=COLORS['Grid'])
        ax.legend(loc="lower left", framealpha=0.9)

        # 2C: Continuous s-plane Pole Trajectories
        ax = axs[1, 0]
        K_sweep_korg = np.linspace(0.0, 2.95, 100)
        K_sweep_ota  = np.linspace(0.0, 1.95, 100)
        w0 = 2.0 * np.pi * 1000.0

        poles_korg = []
        for K in K_sweep_korg:
            d = 3.0 - K
            roots = np.roots([1.0, d * w0, w0 * w0])
            poles_korg.append(roots)
        poles_korg = np.array(poles_korg)

        poles_ota = []
        for K in K_sweep_ota:
            d = 2.0 - K
            roots = np.roots([1.0, d * w0, w0 * w0])
            poles_ota.append(roots)
        poles_ota = np.array(poles_ota)

        ax.plot(poles_korg[:, 0].real / 1000, poles_korg[:, 0].imag / 1000, '.', color=COLORS['Diode'], label="Korg-35 ($d = 3 - K$)", ms=3)
        ax.plot(poles_korg[:, 1].real / 1000, poles_korg[:, 1].imag / 1000, '.', color=COLORS['Diode'], ms=3)
        ax.plot(poles_ota[:, 0].real / 1000, poles_ota[:, 0].imag / 1000, '.', color=COLORS['OTA'], label="KLM-307 OTA ($d = 2 - K$)", ms=3)
        ax.plot(poles_ota[:, 1].real / 1000, poles_ota[:, 1].imag / 1000, '.', color=COLORS['OTA'], ms=3)
        ax.axvline(0, color='black', lw=1.2)
        ax.axhline(0, color='black', lw=1.0, ls=":")

        ax.set_title("2C. Continuous s-plane Pole Locus ($f_c = 1000$ Hz)")
        ax.set_xlabel("Real Axis $\\sigma$ ($krad/s$)")
        ax.set_ylabel("Imaginary Axis $j\\omega$ ($krad/s$)")
        ax.set_xlim(-15, 2)
        ax.set_ylim(-10, 10)
        ax.grid(True, ls=":", color=COLORS['Grid'])
        ax.legend(loc="upper left", framealpha=0.9)

        # 2D: Discrete z-plane Pole Trajectories inside Unit Circle
        ax = axs[1, 1]
        theta = np.linspace(0, 2 * np.pi, 300)
        ax.plot(np.cos(theta), np.sin(theta), 'k-', lw=1.5, label="Unit Circle ($|z| = 1$)")

        res_sweep = np.linspace(0.0, 0.98, 40)
        z_korg = []
        z_ota = []
        for r in res_sweep:
            _, a_k = get_biquad_coeffs(2000.0, fs, res=r, is_ota=False)
            _, a_o = get_biquad_coeffs(2000.0, fs, res=r, is_ota=True)
            z_korg.append(np.roots(a_k))
            z_ota.append(np.roots(a_o))
        z_korg = np.array(z_korg)
        z_ota = np.array(z_ota)

        ax.plot(z_korg[:, 0].real, z_korg[:, 0].imag, 'o', color=COLORS['Diode'], ms=3, label="Korg-35 Poles")
        ax.plot(z_korg[:, 1].real, z_korg[:, 1].imag, 'o', color=COLORS['Diode'], ms=3)
        ax.plot(z_ota[:, 0].real, z_ota[:, 0].imag, 's', color=COLORS['OTA'], ms=3, label="KLM-307 OTA Poles")
        ax.plot(z_ota[:, 1].real, z_ota[:, 1].imag, 's', color=COLORS['OTA'], ms=3)

        ax.set_title("2D. Discrete z-plane Root Locus ($f_c = 2000$ Hz, $f_s = 48$ kHz)")
        ax.set_xlabel("Re($z$)")
        ax.set_ylabel("Im($z$)")
        ax.set_xlim(-1.2, 1.2)
        ax.set_ylim(-1.2, 1.2)
        ax.set_aspect('equal')
        ax.grid(True, ls=":", color=COLORS['Grid'])
        ax.legend(loc="upper left", framealpha=0.9)

        plt.tight_layout(rect=[0, 0, 1, 0.96])
        fig.savefig("docs/page2_topology_and_damping.png", dpi=200)
        pdf.savefig(fig)
        plt.close(fig)
        fig, axs = plt.subplots(2, 2, figsize=(11, 8.5))
        fig.suptitle("MS-20 Filter Suite — Nonlinearities, Waveshaping & Harmonic Spectra", fontsize=15, y=0.98, weight='bold')

        # 3A: V-I Transfer Functions: BJT Asymmetric Resistance vs Symmetric Diodes
        ax = axs[0, 0]
        v_in = np.linspace(-3.0, 3.0, 300)
        # BJT reverse saturation characteristic (alpha = 0.25)
        alpha = 0.25
        phi_bjt_vals = []
        for v in v_in:
            if v >= 0:
                phi_bjt_vals.append((1.0 - np.exp(-v)) / (alpha + (1.0 - alpha) * np.exp(-v)))
            else:
                phi_bjt_vals.append((np.exp(v) - 1.0) / (alpha * np.exp(v) + (1.0 - alpha)))
        phi_bjt_vals = np.array(phi_bjt_vals)

        # Symmetrical Diode Limiter
        f_diode_vals = v_in / np.sqrt(1.0 + v_in * v_in)

        ax.plot(v_in, v_in, 'k--', label="Linear Resistor ($I = V$)", lw=1.2, alpha=0.6)
        ax.plot(v_in, f_diode_vals, color=COLORS['Diode'], lw=2.2, label="Forward Antiparallel Diodes (Symmetric)")
        ax.plot(v_in, phi_bjt_vals, color=COLORS['Circuit'], lw=2.2, label="BJT Reverse Saturation (Asymmetric $\\alpha_R=0.25$)")
        ax.axhline(0, color='gray', lw=0.8, ls=":")
        ax.axvline(0, color='gray', lw=0.8, ls=":")

        ax.set_title("3A. Circuit Nonlinear Characteristics: BJT vs Diode")
        ax.set_xlabel("Normalized Terminal Voltage $V$")
        ax.set_ylabel("Normalized Current / Conduction $I$")
        ax.set_ylim(-2.5, 4.5)
        ax.set_xlim(-3.0, 3.0)
        ax.grid(True, ls=":", color=COLORS['Grid'])
        ax.legend(loc="upper left", framealpha=0.9)

        # 3B: Time-Domain Output Waveforms under Hot Overdrive
        ax = axs[0, 1]
        t = np.arange(480) / fs # 10 ms window
        src_overdrive = 1.8 * np.sin(2.0 * np.pi * 200.0 * t)

        y_sk, _, _ = simulate_nonlinear_step(src_overdrive, fs, 2500.0, 0.2, 1.0, model='Diode')
        # Simulate SK linearly
        b_sk, a_sk = get_biquad_coeffs(2500.0, fs, res=0.2, mode=0)
        y_sk_lin = signal.lfilter(b_sk, a_sk, src_overdrive)

        y_diode, _, _ = simulate_nonlinear_step(src_overdrive, fs, 2500.0, 0.2, drive=3.0, model='Diode')
        y_ota, _, _   = simulate_nonlinear_step(src_overdrive, fs, 2500.0, 0.2, drive=3.0, model='OTA')
        y_circ, _, _  = simulate_nonlinear_step(src_overdrive, fs, 2500.0, 0.2, drive=3.0, model='Circuit')

        ax.plot(t * 1000, y_sk_lin, '--', color=COLORS['SK'], lw=1.5, label="MS20SK (Linear Baseline)")
        ax.plot(t * 1000, y_diode, color=COLORS['Diode'], lw=2.0, label="MS20Diode (Symmetric Compression)")
        ax.plot(t * 1000, y_ota, color=COLORS['OTA'], lw=2.0, label="MS20OTA (Passband Clean!)")
        ax.plot(t * 1000, y_circ, color=COLORS['Circuit'], lw=2.0, label="MS20Circuit (Asymmetric BJT Shape)")

        ax.set_title("3B. Output Waveforms under Overdrive (200 Hz Sine, Drive = 3.0)")
        ax.set_xlabel("Time (ms)")
        ax.set_ylabel("Output Amplitude")
        ax.set_ylim(-2.0, 2.0)
        ax.set_xlim(0, 10)
        ax.grid(True, ls=":", color=COLORS['Grid'])
        ax.legend(loc="upper right", framealpha=0.9)

        # 3C: Harmonic Spectra (FFT) Bar Chart Comparison
        ax = axs[1, 0]
        # Run long simulation for accurate FFT
        t_long = np.arange(9600) / fs
        src_fft = 1.8 * np.sin(2.0 * np.pi * 200.0 * t_long)

        y_sk_fft = signal.lfilter(b_sk, a_sk, src_fft)

        models = ['MS20SK', 'MS20Diode', 'MS20OTA', 'MS20Circuit']
        sim_data = {
            'MS20SK': y_sk_fft,
            'MS20Diode': simulate_nonlinear_step(src_fft, fs, 2500.0, 0.2, drive=3.0, model='Diode')[0],
            'MS20OTA':   simulate_nonlinear_step(src_fft, fs, 2500.0, 0.2, drive=3.0, model='OTA')[0],
            'MS20Circuit': simulate_nonlinear_step(src_fft, fs, 2500.0, 0.2, drive=3.0, model='Circuit')[0],
        }

        # Calculate FFT harmonic amplitudes
        harmonics = [200, 400, 600, 800, 1000] # f0, 2f0, 3f0, 4f0, 5f0
        harm_names = ["1st ($f_0$)", "2nd ($2f_0$)\n[EVEN]", "3rd ($3f_0$)\n[ODD]", "4th ($4f_0$)\n[EVEN]", "5th ($5f_0$)\n[ODD]"]

        bar_width = 0.18
        x_indices = np.arange(len(harmonics))

        for idx, (m_name, m_color) in enumerate([
            ('MS20SK', COLORS['SK']),
            ('MS20Diode', COLORS['Diode']),
            ('MS20OTA', COLORS['OTA']),
            ('MS20Circuit', COLORS['Circuit'])
        ]):
            y_sig = sim_data[m_name]
            # Use last 4800 samples with Hann window
            sig_win = y_sig[-4800:] * np.hanning(4800)
            fft_mag = np.abs(np.fft.rfft(sig_win))
            freqs = np.fft.rfftfreq(4800, 1.0 / fs)

            f0_amp = fft_mag[np.argmin(np.abs(freqs - 200.0))]
            ratios = []
            for h_freq in harmonics:
                h_idx = np.argmin(np.abs(freqs - h_freq))
                amp = fft_mag[h_idx]
                ratios.append(amp / f0_amp * 100.0)

            ax.bar(x_indices + (idx - 1.5) * bar_width, ratios, width=bar_width, label=m_name, color=m_color, alpha=0.9)

        ax.set_title("3C. Harmonic Distortion Spectra (200 Hz Tone under Overdrive)")
        ax.set_xticks(x_indices)
        ax.set_xticklabels(harm_names)
        ax.set_ylabel("Amplitude relative to Fundamental (%)")
        ax.set_yscale('log')
        ax.set_ylim(0.01, 150)
        ax.grid(True, which="both", ls=":", color=COLORS['Grid'])
        ax.legend(loc="upper right", framealpha=0.9)

        # 3D: MS20OTA Passband Immunity vs Corner Saturation
        ax = axs[1, 1]
        t_corner = np.arange(9600) / fs
        # 1. Passband tone: 100 Hz with fc = 3000 Hz
        src_pass = np.sin(2.0 * np.pi * 100.0 * t_corner)
        y_ota_pass_low, _, _  = simulate_nonlinear_step(src_pass, fs, 3000.0, 0.4, drive=1.0, model='OTA')
        y_ota_pass_high, _, _ = simulate_nonlinear_step(src_pass, fs, 3000.0, 0.4, drive=4.0, model='OTA')

        # 2. Resonant Corner tone: 3000 Hz with fc = 3000 Hz
        src_peak = np.sin(2.0 * np.pi * 3000.0 * t_corner)
        y_ota_peak_low, _, _  = simulate_nonlinear_step(src_peak, fs, 3000.0, 0.7, drive=1.0, model='OTA')
        y_ota_peak_high, _, _ = simulate_nonlinear_step(src_peak, fs, 3000.0, 0.7, drive=4.0, model='OTA')

        # Plot 2 ms snippet of peak vs passband
        t_ms = t_corner[:240] * 1000
        ax.plot(t_ms, y_ota_peak_low[:240], color='#2ca02c', lw=1.8, label="Resonant Peak: Drive = 1.0 (Tall)")
        ax.plot(t_ms, y_ota_peak_high[:240], color=COLORS['OTA'], lw=2.2, label="Resonant Peak: Drive = 4.0 (Compressed)")
        ax.plot(t_ms, y_ota_pass_low[:240], '--', color='gray', lw=1.4, label="Passband (100 Hz): Drive = 1.0")
        ax.plot(t_ms, y_ota_pass_high[:240], ':', color='black', lw=1.4, label="Passband (100 Hz): Drive = 4.0 (Identical!)")

        ax.set_title("3D. MS20OTA Clean Passband Immunity vs Corner Limiting")
        ax.set_xlabel("Time (ms)")
        ax.set_ylabel("Signal Amplitude")
        ax.grid(True, ls=":", color=COLORS['Grid'])
        ax.legend(loc="upper right", framealpha=0.9)

        plt.tight_layout(rect=[0, 0, 1, 0.96])
        fig.savefig("docs/page3_nonlinear_drive_harmonics.png", dpi=200)
        pdf.savefig(fig)
        plt.close(fig)

        # =====================================================================
        # PAGE 4: Autonomous Limit Cycles & Audio-Rate Filter FM
        # =====================================================================
        fig, axs = plt.subplots(2, 2, figsize=(11, 8.5))
        fig.suptitle("MS-20 Filter Suite — Limit-Cycle Self-Oscillation & Audio-Rate FM", fontsize=15, y=0.98, weight='bold')

        # 4A: State-Space Phase Portrait (vC1 vs vC2) in Self-Oscillation
        ax = axs[0, 0]
        # Impulse kick at t=0, then silence
        x_kick = np.zeros(9600)
        x_kick[0] = 0.01

        _, vc1_diode, vc2_diode = simulate_nonlinear_step(x_kick, fs, 1200.0, res=0.90, drive=2.0, model='Diode')
        _, vc1_ota, vc2_ota     = simulate_nonlinear_step(x_kick, fs, 1200.0, res=0.90, drive=2.0, model='OTA')
        _, vc1_circ, vc2_circ   = simulate_nonlinear_step(x_kick, fs, 1200.0, res=0.90, drive=2.0, model='Circuit')

        # Plot steady state limit cycle orbits (last 1000 samples)
        ax.plot(vc1_diode[-800:], vc2_diode[-800:], color=COLORS['Diode'], lw=2.0, label="MS20Diode Orbit")
        ax.plot(vc1_ota[-800:], vc2_ota[-800:], color=COLORS['OTA'], lw=2.0, label="MS20OTA Orbit")
        ax.plot(vc1_circ[-800:], vc2_circ[-800:], color=COLORS['Circuit'], lw=2.0, label="MS20Circuit Orbit (Asymmetric)")

        ax.set_title("4A. State-Space Phase Portrait ($v_{C1}$ vs $v_{C2}$) Limit Cycle")
        ax.set_xlabel("Capacitor State $v_{C1}$")
        ax.set_ylabel("Capacitor State $v_{C2}$")
        ax.grid(True, ls=":", color=COLORS['Grid'])
        ax.legend(loc="upper right", framealpha=0.9)

        # 4B: Self-Oscillation Time-Domain Waveforms
        ax = axs[0, 1]
        t_osc = np.arange(300) / fs * 1000 # 6.25 ms window
        # Get output waveforms
        y_osc_diode, _, _ = simulate_nonlinear_step(x_kick, fs, 800.0, res=0.90, drive=2.0, model='Diode')
        y_osc_ota, _, _   = simulate_nonlinear_step(x_kick, fs, 800.0, res=0.90, drive=2.0, model='OTA')
        y_osc_circ, _, _  = simulate_nonlinear_step(x_kick, fs, 800.0, res=0.90, drive=2.0, model='Circuit')

        ax.plot(t_osc, y_osc_diode[-300:], color=COLORS['Diode'], lw=2.0, label="MS20Diode ($V_{out} = f(V_2)$)")
        ax.plot(t_osc, y_osc_ota[-300:], color=COLORS['OTA'], lw=2.0, label="MS20OTA (Pure Sine Orbit)")
        ax.plot(t_osc, y_osc_circ[-300:], color=COLORS['Circuit'], lw=2.0, label="MS20Circuit (Asymmetric Waveform)")

        ax.set_title("4B. Autonomous Self-Oscillating Waveforms ($f_c = 800$ Hz)")
        ax.set_xlabel("Time (ms)")
        ax.set_ylabel("Output Voltage")
        ax.set_ylim(-1.5, 1.5)
        ax.grid(True, ls=":", color=COLORS['Grid'])
        ax.legend(loc="upper right", framealpha=0.9)

        # 4C: Audio-Rate Frequency Modulation (Filter FM) Time Signal
        ax = axs[1, 0]
        t_fm = np.arange(9600) / fs
        carrier = signal.sawtooth(2.0 * np.pi * 110.0 * t_fm)
        mod_freq = 220.0
        # Cutoff modulates smoothly between 400 and 4000 Hz at 220 Hz
        fc_mod = 2200.0 + 1800.0 * np.sin(2.0 * np.pi * mod_freq * t_fm)

        # Simulate per-sample audio-rate FM for MS20Circuit
        y_fm_circ = np.zeros(len(carrier))
        s1 = 0.0
        s2 = 0.0
        v1 = 0.0
        v2 = 0.0
        drive_fm = 2.0
        inv_d_fm = 1.0 / drive_fm
        alpha = 0.25

        def phi_quick(v):
            nu = drive_fm * v
            clipped = min(abs(nu), 30.0)
            exp_neg = np.exp(-clipped)
            if nu >= 0:
                den = alpha + (1.0 - alpha) * exp_neg
                return ((1.0 - exp_neg) / den) * inv_d_fm, exp_neg / (den * den)
            else:
                den = alpha * exp_neg + (1.0 - alpha)
                return ((exp_neg - 1.0) / den) * inv_d_fm, exp_neg / (den * den)

        for n in range(len(carrier)):
            g_n = np.tan(np.pi * fc_mod[n] / fs)
            xn = carrier[n]
            s1_s2 = s1 + s2
            for _ in range(3):
                p1, dp1 = phi_quick(xn - v1)
                p2, dp2 = phi_quick(v1 - v2)
                arg = drive_fm * v2
                d = np.sqrt(1.0 + arg * arg)
                fv2 = (arg / d) * inv_d_fm
                dfv2 = 1.0 / (d * (1.0 + arg * arg))
                F1 = v1 + v2 - 2.8 * fv2 - g_n * p1 - s1_s2
                F2 = v2 - g_n * p2 - s2
                j11 = 1.0 + g_n * dp1
                j12 = 1.0 - 2.8 * dfv2
                j21 = -g_n * dp2
                j22 = 1.0 + g_n * dp2
                det = j11 * j22 - j12 * j21
                inv_det = 1.0 / det if abs(det) > 1e-12 else 1.0
                v1 += -(j22 * F1 - j12 * F2) * inv_det
                v2 += -(-j21 * F1 + j11 * F2) * inv_det

            arg = drive_fm * v2
            d = np.sqrt(1.0 + arg * arg)
            fv2_final = (arg / d) * inv_d_fm
            vc2 = v2
            vc1 = v1 - 2.8 * fv2_final
            y_fm_circ[n] = fv2_final
            s1 = 2.0 * vc1 - s1
            s2 = 2.0 * vc2 - s2

        t_plot_fm = t_fm[:480] * 1000
        ax.plot(t_plot_fm, carrier[:480] * 0.5, '--', color='gray', lw=1.2, label="110 Hz Saw Carrier")
        ax.plot(t_plot_fm, y_fm_circ[:480], color=COLORS['Circuit'], lw=1.8, label="MS20Circuit FM Output")

        ax.set_title("4C. Audio-Rate Filter FM Time Signal (220 Hz Modulator)")
        ax.set_xlabel("Time (ms)")
        ax.set_ylabel("Amplitude")
        ax.set_ylim(-1.5, 1.5)
        ax.grid(True, ls=":", color=COLORS['Grid'])
        ax.legend(loc="upper right", framealpha=0.9)

        # 4D: Audio-Rate FM FFT Spectrum (Bessel Sidebands)
        ax = axs[1, 1]
        fft_fm = np.abs(np.fft.rfft(y_fm_circ[-4800:] * np.hanning(4800)))
        freqs_fm = np.fft.rfftfreq(4800, 1.0 / fs)

        ax.plot(freqs_fm, 20.0 * np.log10(fft_fm / np.max(fft_fm) + 1e-6), color=COLORS['Circuit'], lw=1.5, label="MS20Circuit FM Spectrum")
        ax.set_title("4D. Audio-Rate FM Spectrum (Rich Sidebands)")
        ax.set_xlabel("Frequency (Hz)")
        ax.set_ylabel("Normalized Magnitude (dB)")
        ax.set_xlim(50, 6000)
        ax.set_ylim(-60, 5)
        ax.grid(True, ls=":", color=COLORS['Grid'])
        ax.legend(loc="upper right", framealpha=0.9)

        plt.tight_layout(rect=[0, 0, 1, 0.96])
        fig.savefig("docs/page4_limit_cycles_and_fm.png", dpi=200)
        pdf.savefig(fig)
        plt.close(fig)

    print(f"SUCCESS: High-resolution filter curves PDF generated at: {output_path}")

if __name__ == '__main__':
    generate_pdf()
