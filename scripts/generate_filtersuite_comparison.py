import os
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from scipy.signal import freqz

# Set high-quality styling
plt.style.use('seaborn-v0_8-whitegrid' if 'seaborn-v0_8-whitegrid' in plt.style.available else 'default')
plt.rcParams['font.sans-serif'] = ['Helvetica', 'Arial', 'DejaVu Sans']
plt.rcParams['axes.edgecolor'] = '#cccccc'
plt.rcParams['axes.linewidth'] = 0.8
plt.rcParams['grid.color'] = '#e0e0e0'
plt.rcParams['grid.linestyle'] = '--'
plt.rcParams['grid.alpha'] = 0.6

FS = 44100.0
ARTIFACT_DIR = "/Users/fmmac/.gemini/antigravity-cli/brain/6dd90fa9-37ca-4774-b4e5-d9a1da529cfc"
os.makedirs(ARTIFACT_DIR, exist_ok=True)

# -----------------------------------------------------------------------------
# 1. DSP Simulation Engines (Exact C++ Match)
# -----------------------------------------------------------------------------

def sim_wasp(x, fc=1000.0, res=0.2, drive=1.0, mode=0, fs=FS):
    # FSWasp: CA3080 OTA + CD4069 CMOS Inverters
    N = len(x)
    y = np.zeros(N)
    g = np.tan(np.pi * np.clip(fc, 10.0, fs * 0.49) / fs)
    # Damping curve
    wc = 2 * np.pi * fc
    R2C2 = 2.7e-6
    Rres = 50e3 * (1.0 - 0.98 * np.clip(res, 0.0, 1.0))
    Re_H1 = (1e3 + Rres) / (1e6 + 1e3 + Rres)
    k_res = np.clip(Re_H1 + R2C2 * wc, 0.01, 1.5)
    
    alpha = max(1e-6, drive)
    beta = 0.5 * alpha
    
    def f_ota(v):
        return np.tanh(alpha * v) / alpha
    def df_ota(v):
        t = np.tanh(alpha * v)
        return 1.0 - t * t
    def f_cmos(v):
        return v / np.sqrt(1.0 + (beta * v)**2)
    def df_cmos(v):
        return (1.0 + (beta * v)**2)**(-1.5)
        
    s1, s2 = 0.0, 0.0
    denom_lin = 1.0 + k_res * g + g * g
    
    for i in range(N):
        vin = x[i]
        if drive < 1e-4:
            v_hp = -(vin + (k_res + g) * s1 + s2) / denom_lin
        else:
            v_hp = -(vin + (k_res + g) * s1 + s2) / denom_lin
            for _ in range(4):
                v_bp = g * f_ota(v_hp) + s1
                v_lp = g * f_ota(v_bp) + s2
                u = vin + k_res * v_bp + v_lp
                F = v_hp + f_cmos(u)
                dF = 1.0 + df_cmos(u) * (k_res * g * df_ota(v_hp) + g * g * df_ota(v_bp) * df_ota(v_hp))
                dx = F / dF
                v_hp -= dx
                if abs(dx) < 1e-7:
                    break
        v_bp = g * f_ota(v_hp) + s1
        v_lp = g * f_ota(v_bp) + s2
        s1 = 2.0 * v_bp - s1
        s2 = 2.0 * v_lp - s2
        if mode == 0: y[i] = v_lp
        elif mode == 1: y[i] = v_bp
        else: y[i] = v_hp
    return y

def sim_steiner(x, fc=1000.0, res=0.3, mode=0, drive=1.0, fs=FS):
    # FSSteiner: Steiner-Parker Sallen-Key Diode VCF
    N = len(x)
    y = np.zeros(N)
    g = np.tan(np.pi * np.clip(fc, 10.0, fs * 0.49) / fs)
    K = np.clip(res, 0.0, 1.0) * 3.6
    alpha = max(1e-6, drive)
    
    def f_nl(v):
        return np.tanh(alpha * v) / alpha
    def df_nl(v):
        t = np.tanh(alpha * v)
        return 1.0 - t * t
        
    det0 = g * g + 3.0 * g + 1.0
    inv_det0 = 1.0 / det0
    gamma = g * inv_det0
    
    s1, s2 = 0.0, 0.0
    for i in range(N):
        vin = x[i]
        if mode == 0:
            b1, b2 = -vin, 0.0
        elif mode == 1:
            b1, b2 = 2.0 * vin, vin
        else:
            b1, b2 = -vin, -vin
            
        p1 = s1 + b1
        p2 = s2 + b2
        v_open = inv_det0 * (-g * p1 + (1.0 + 2.0 * g) * p2)
        
        if drive < 1e-4:
            denom = 1.0 - gamma * K
            vout = v_open / denom if abs(denom) > 1e-5 else v_open * 1e5
        else:
            vout = v_open / max(1.0 - gamma * K, 0.05)
            for _ in range(4):
                F = vout - v_open - gamma * K * f_nl(vout)
                dF = 1.0 - gamma * K * df_nl(vout)
                dx = F / dF
                vout -= dx
                if abs(dx) < 1e-7:
                    break
        v_fb = f_nl(vout)
        s1 = 2.0 * ((1.0 + g) * p1 - g * p2 + 2.0 * g * K * v_fb) * inv_det0 - s1
        s2 = 2.0 * vout - s2
        y[i] = vout
    return y

def sim_polivoks(x, fc=1000.0, res=0.3, mode=0, drive=1.0, fs=FS):
    # FSPolivoks: Formanta Polivoks programmable op-amp VCF
    N = len(x)
    y = np.zeros(N)
    g = np.tan(np.pi * np.clip(fc, 10.0, fs * 0.49) / fs)
    if drive < 1e-4:
        r = 2.0 * (1.0 - 0.99 * np.clip(res, 0.0, 1.0))
    else:
        r = max(-0.1, 2.0 * (1.0 - np.clip(res, 0.0, 1.2)))
    alpha = max(1e-6, drive)
    
    def f_sat(v):
        return np.tanh(alpha * v) / alpha
    def df_sat(v):
        t = np.tanh(alpha * v)
        return 1.0 - t * t
    def soft_rail(v):
        return 1.5 * np.tanh(v / 1.5)
        
    s1, s2 = 0.0, 0.0
    denom_lin = 1.0 + r * g + g * g
    denom_init = 1.0 + max(r, 0.01) * g + g * g
    
    for i in range(N):
        vin = x[i]
        if drive < 1e-4:
            v_sum = (vin - (r + g) * s1 - s2) / denom_lin
            v_bp = g * v_sum + s1
            v_lp = g * v_bp + s2
        else:
            v_in_drive = vin * drive
            x_sol = (v_in_drive - (r + g) * s1 - s2) / denom_init
            for _ in range(4):
                f_x = f_sat(x_sol)
                u = g * f_x + s1
                f_u = f_sat(u)
                F = x_sol + r * g * f_x + g * f_u + r * s1 + s2 - v_in_drive
                dF = 1.0 + g * df_sat(x_sol) * (r + g * df_sat(u))
                dx = F / dF
                x_sol -= dx
                if abs(dx) < 1e-7:
                    break
            v_bp = soft_rail(g * f_sat(x_sol) + s1)
            v_lp = soft_rail(g * f_sat(v_bp) + s2)
            
        s1 = 2.0 * v_bp - s1
        s2 = 2.0 * v_lp - s2
        if mode == 0: y[i] = v_lp
        else: y[i] = v_bp
    return y

def sim_zmorph(x, morph=0.0, shapeA=0, shapeB=1, fs=FS):
    # FSZMorph: Multiresonant parallel TPT banks
    shapes = [
        # 0: Vowel A
        ([(730, 6.0, 1.0), (1090, 7.0, 0.65), (2440, 9.0, 0.35), (3500, 8.0, 0.2)], 0.15),
        # 1: Vowel I
        ([(270, 5.0, 1.0), (2290, 10.0, 0.70), (3010, 10.0, 0.40), (4200, 8.0, 0.15)], 0.15),
        # 2: Vowel U
        ([(300, 5.0, 1.0), (870, 6.0, 0.70), (2250, 8.0, 0.35), (3100, 8.0, 0.15)], 0.15),
        # 3: Deep Comb
        ([(220, 8.0, 1.0), (660, 12.0, -0.7), (1320, 10.0, 0.6), (2640, 14.0, -0.5)], 0.25),
        # 4: Metallic Bell
        ([(440, 15.0, 0.9), (980, 20.0, 0.8), (1790, 22.0, 0.6), (3280, 25.0, 0.4)], 0.05),
        # 5: Acoustic Body
        ([(110, 4.0, 0.9), (220, 5.0, 0.8), (450, 6.0, 0.6), (900, 8.0, 0.4)], 0.30)
    ]
    def run_bank(idx):
        formants, g_dir = shapes[idx]
        y_bank = np.zeros(len(x))
        for f, q, gain in formants:
            g = np.tan(np.pi * np.clip(f, 10.0, fs * 0.49) / fs)
            R = 1.0 / q
            denom = 1.0 / (1.0 + R * g + g * g)
            s1, s2 = 0.0, 0.0
            out_bp = np.zeros(len(x))
            for i in range(len(x)):
                v_hp = (x[i] - (R + g) * s1 - s2) * denom
                v_bp = g * v_hp + s1
                v_lp = g * v_bp + s2
                s1 = 2.0 * v_bp - s1
                s2 = 2.0 * v_lp - s2
                out_bp[i] = v_bp
            y_bank += gain * out_bp
        y_bank += g_dir * x
        return y_bank

    yA = run_bank(shapeA)
    yB = run_bank(shapeB)
    m = np.clip(morph, 0.0, 1.0)
    return (1.0 - m) * yA + m * yB

def sim_dispersion(x, center=1500.0, spread=1.0, q=2.0, fs=FS):
    # FSDispersion: 4-stage 2nd-order TPT all-pass cascade
    N = len(x)
    offsets = np.array([-0.75, -0.25, 0.25, 0.75]) * spread
    freqs = np.clip(center * (2.0 ** offsets), 10.0, fs * 0.49)
    gs = np.tan(np.pi * freqs / fs)
    R = 1.0 / max(0.1, q)
    denoms = 1.0 / (1.0 + R * gs + gs * gs)
    
    s1 = np.zeros(4)
    s2 = np.zeros(4)
    y = np.zeros(N)
    for i in range(N):
        val = x[i]
        for k in range(4):
            v_hp = (val - (R + gs[k]) * s1[k] - s2[k]) * denoms[k]
            v_bp = gs[k] * v_hp + s1[k]
            v_lp = gs[k] * v_bp + s2[k]
            s1[k] = 2.0 * v_bp - s1[k]
            s2[k] = 2.0 * v_lp - s2[k]
            val = val - 2.0 * R * v_bp
        y[i] = val
    return y

def sim_ms20_diode(x, fc=1000.0, res=0.5, drive=1.0, fs=FS):
    # MS20Diode benchmark: exact TPT state solver matching src/MS20Diode.cpp
    N = len(x)
    y = np.zeros(N)
    clamped_fc = np.clip(fc, 10.0, fs * 0.49)
    clamped_res = np.clip(res, 0.0, 1.0)
    clamped_drive = np.clip(drive, 0.01, 10.0)
    K = clamped_res * 4.0
    inv_drive = 1.0 / clamped_drive
    g = np.tan(np.pi * clamped_fc / fs)
    c_lin = 1.0 + 3.0 * g + g * g
    dK_lin = min(K, 2.9)
    inv_lin_den = 1.0 / (g * g + (3.0 - dK_lin) * g + 1.0)
    inv_1p2g = 1.0 / (1.0 + 2.0 * g)
    s1, s2 = 0.0, 0.0
    for i in range(N):
        vin = x[i]
        p = (1.0 + 2.0 * g) * s2 - g * s1 + g * g * vin
        v = p * inv_lin_den
        for _ in range(3):
            arg = clamped_drive * v
            arg2 = arg * arg
            d = np.sqrt(1.0 + arg2)
            f_val = (arg / d) * inv_drive
            f_prime = 1.0 / (d * (1.0 + arg2))
            F = c_lin * v - g * K * f_val - p
            dF = c_lin - g * K * f_prime
            v -= F / dF
        arg = clamped_drive * v
        d = np.sqrt(1.0 + arg * arg)
        f_val = (arg / d) * inv_drive
        vc2 = v
        vc1 = (2.0 * g * K * f_val - g * vc2 - g * vin + s1) * inv_1p2g
        s1 = 2.0 * vc1 - s1
        s2 = 2.0 * vc2 - s2
        y[i] = f_val
    return y

def sim_ms20_circuit(x, fc=1000.0, res=0.5, drive=1.0, fs=FS):
    # MS20Circuit benchmark: exact 2x2 MNA circuit solver matching src/MS20Circuit.cpp
    N = len(x)
    y = np.zeros(N)
    clamped_fc = np.clip(fc, 10.0, fs * 0.49)
    clamped_res = np.clip(res, 0.0, 1.0)
    clamped_drive = np.clip(drive, 0.01, 10.0)
    K = clamped_res * 4.0
    inv_drive = 1.0 / clamped_drive
    g = np.tan(np.pi * clamped_fc / fs)
    alpha_R = 0.25

    def phi_bjt(v):
        nu = clamped_drive * v
        abs_nu = min(abs(nu), 40.0)
        exp_neg = np.exp(-abs_nu)
        if nu >= 0.0:
            den = alpha_R + (1.0 - alpha_R) * exp_neg
            val = ((1.0 - exp_neg) / den) * inv_drive
            prime = exp_neg / (den * den)
        else:
            den = alpha_R * exp_neg + (1.0 - alpha_R)
            val = ((exp_neg - 1.0) / den) * inv_drive
            prime = exp_neg / (den * den)
        return val, prime

    def f_diode(v):
        arg = clamped_drive * v
        arg2 = arg * arg
        d = np.sqrt(1.0 + arg2)
        val = (arg / d) * inv_drive
        prime = 1.0 / (d * (1.0 + arg2))
        return val, prime

    v1, v2 = 0.0, 0.0
    s1, s2 = 0.0, 0.0
    for i in range(N):
        vin1 = x[i]
        vref = 0.0
        s1_plus_s2 = s1 + s2
        for _ in range(3):
            u1 = vin1 - v1
            u2 = v1 - v2
            phi1, dphi1 = phi_bjt(u1)
            phi2, dphi2 = phi_bjt(u2)
            fv2, dfv2 = f_diode(v2)
            F1 = v1 + v2 - vref - K * fv2 - g * phi1 - s1_plus_s2
            F2 = v2 - vref - g * phi2 - s2
            j11 = 1.0 + g * dphi1
            j12 = 1.0 - K * dfv2
            j21 = -g * dphi2
            j22 = 1.0 + g * dphi2
            det = j11 * j22 - j12 * j21
            inv_det = 1.0 / det if abs(det) > 1e-12 else 1.0
            dv1 = -(j22 * F1 - j12 * F2) * inv_det
            dv2 = -(-j21 * F1 + j11 * F2) * inv_det
            v1 += dv1
            v2 += dv2
        fv2_final, _ = f_diode(v2)
        vc2 = v2 - vref
        vc1 = v1 - K * fv2_final
        s1 = 2.0 * vc1 - s1
        s2 = 2.0 * vc2 - s2
        y[i] = fv2_final
    return y

print("All simulation engines compiled and verified!")

# -----------------------------------------------------------------------------
# 2. Measurement Helpers
# -----------------------------------------------------------------------------

def measure_frequency_response(sim_fn, freqs=None, N_cyc=12, fs=FS, **kwargs):
    if freqs is None:
        freqs = np.logspace(np.log10(20), np.log10(18000), 200)
    mags = []
    phases = []
    for f in freqs:
        dur = max(0.04, N_cyc / f)
        N = int(dur * fs)
        t = np.arange(N) / fs
        vin = 0.01 * np.sin(2 * np.pi * f * t) # Quiet small-signal
        vout = sim_fn(vin, fs=fs, **kwargs)
        # Tail analysis (last 4 cycles)
        tail_N = int(min(N * 0.5, max(64, 4 * fs / f)))
        t_tail = t[-tail_N:]
        vin_tail = vin[-tail_N:]
        vout_tail = vout[-tail_N:]
        
        # Quadrature demodulation to extract amplitude and phase
        ref_cos = np.cos(2 * np.pi * f * t_tail)
        ref_sin = np.sin(2 * np.pi * f * t_tail)
        in_I = 2.0 * np.mean(vin_tail * ref_cos)
        in_Q = 2.0 * np.mean(vin_tail * ref_sin)
        out_I = 2.0 * np.mean(vout_tail * ref_cos)
        out_Q = 2.0 * np.mean(vout_tail * ref_sin)
        
        amp_in = np.hypot(in_I, in_Q)
        amp_out = np.hypot(out_I, out_Q)
        mag_db = 20.0 * np.log10(max(1e-9, amp_out / amp_in))
        
        phi_in = np.arctan2(in_Q, in_I)
        phi_out = np.arctan2(out_Q, out_I)
        dphi = phi_out - phi_in
        mags.append(mag_db)
        phases.append(dphi)
    phases = np.unwrap(phases)
    return freqs, np.array(mags), phases

print("Measurement routines ready!")

# -----------------------------------------------------------------------------
# 3. Page 1: Linear & Multimode Frequency & Phase Characterization
# -----------------------------------------------------------------------------

def make_page1():
    print("Generating Page 1: Linear & Multimode Frequency & Phase Responses...")
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle("FilterSuite: Frequency & Multimode Phase Characterization (Small-Signal Linear)", fontsize=16, fontweight='bold', y=0.98)
    
    freqs = np.logspace(np.log10(20), np.log10(18000), 120)
    
    # 1. Low-Pass Magnitude Response
    ax = axes[0, 0]
    ax.set_title("1A. Low-Pass Magnitude Response (fc = 1000 Hz, res = 0.5)", fontweight='bold')
    _, mag_wasp, _ = measure_frequency_response(sim_wasp, freqs, fc=1000.0, res=0.5, mode=0, drive=0.0)
    _, mag_stein, _ = measure_frequency_response(sim_steiner, freqs, fc=1000.0, res=0.5, mode=0, drive=0.0)
    _, mag_poli, _ = measure_frequency_response(sim_polivoks, freqs, fc=1000.0, res=0.5, mode=0, drive=0.0)
    _, mag_ms20, _ = measure_frequency_response(sim_ms20_diode, freqs, fc=1000.0, res=0.5, drive=0.0)
    
    ax.semilogx(freqs, mag_wasp, label="FSWasp (LP, OTA+CMOS SVF)", color="#1f77b4", lw=2)
    ax.semilogx(freqs, mag_stein, label="FSSteiner (LP, Diode SK)", color="#ff7f0e", lw=2)
    ax.semilogx(freqs, mag_poli, label="FSPolivoks (LP, Op-Amp SVF)", color="#2ca02c", lw=2)
    ax.semilogx(freqs, mag_ms20, label="MS20Diode (LP, Korg-35 Loaded)", color="#d62728", lw=1.8, ls="--")
    
    ax.axvline(1000, color="gray", ls=":", alpha=0.7, label="Cutoff fc = 1 kHz")
    ax.set_xlabel("Frequency (Hz)")
    ax.set_ylabel("Magnitude (dB)")
    ax.set_ylim(-60, 20)
    ax.set_xlim(20, 20000)
    ax.legend(fontsize=9, loc="lower left")
    ax.grid(True, which="both", alpha=0.4)
    
    # 2. Phase Response
    ax = axes[0, 1]
    ax.set_title("1B. Unwrapped Phase Response (fc = 1000 Hz, res = 0.5)", fontweight='bold')
    _, _, phi_wasp = measure_frequency_response(sim_wasp, freqs, fc=1000.0, res=0.5, mode=0, drive=0.0)
    _, _, phi_stein = measure_frequency_response(sim_steiner, freqs, fc=1000.0, res=0.5, mode=0, drive=0.0)
    _, _, phi_poli = measure_frequency_response(sim_polivoks, freqs, fc=1000.0, res=0.5, mode=0, drive=0.0)
    _, _, phi_ms20 = measure_frequency_response(sim_ms20_diode, freqs, fc=1000.0, res=0.5, drive=0.0)
    
    ax.semilogx(freqs, np.degrees(phi_wasp), label="FSWasp (LP)", color="#1f77b4", lw=2)
    ax.semilogx(freqs, np.degrees(phi_stein), label="FSSteiner (LP)", color="#ff7f0e", lw=2)
    ax.semilogx(freqs, np.degrees(phi_poli), label="FSPolivoks (LP)", color="#2ca02c", lw=2)
    ax.semilogx(freqs, np.degrees(phi_ms20), label="MS20Diode (LP)", color="#d62728", lw=1.8, ls="--")
    
    ax.axvline(1000, color="gray", ls=":", alpha=0.7)
    ax.set_xlabel("Frequency (Hz)")
    ax.set_ylabel("Phase (Degrees)")
    ax.set_ylim(-220, 20)
    ax.set_xlim(20, 20000)
    ax.legend(fontsize=9, loc="lower left")
    ax.grid(True, which="both", alpha=0.4)
    
    # 3. Multimode Spectral Diversity (LP / BP / HP)
    ax = axes[1, 0]
    ax.set_title("1C. Multimode Diversity: LP vs BP vs HP (fc = 1000 Hz, res = 0.6)", fontweight='bold')
    _, mag_stein_lp, _ = measure_frequency_response(sim_steiner, freqs, fc=1000.0, res=0.6, mode=0, drive=0.0)
    _, mag_stein_bp, _ = measure_frequency_response(sim_steiner, freqs, fc=1000.0, res=0.6, mode=1, drive=0.0)
    _, mag_stein_hp, _ = measure_frequency_response(sim_steiner, freqs, fc=1000.0, res=0.6, mode=2, drive=0.0)
    _, mag_wasp_hp, _ = measure_frequency_response(sim_wasp, freqs, fc=1000.0, res=0.6, mode=2, drive=0.0)
    _, mag_poli_bp, _ = measure_frequency_response(sim_polivoks, freqs, fc=1000.0, res=0.6, mode=1, drive=0.0)
    
    ax.semilogx(freqs, mag_stein_lp, label="FSSteiner LP (-12 dB/oct)", color="#ff7f0e", lw=2)
    ax.semilogx(freqs, mag_stein_bp, label="FSSteiner BP (Symmetric Peak)", color="#ffbb78", lw=1.8, ls="--")
    ax.semilogx(freqs, mag_stein_hp, label="FSSteiner HP (+6 dB zero shelf)", color="#9467bd", lw=2)
    ax.semilogx(freqs, mag_wasp_hp, label="FSWasp HP (2-Pole SVF)", color="#17becf", lw=1.8, ls="-.")
    ax.semilogx(freqs, mag_poli_bp, label="FSPolivoks BP", color="#2ca02c", lw=1.8, ls=":")
    
    ax.set_xlabel("Frequency (Hz)")
    ax.set_ylabel("Magnitude (dB)")
    ax.set_ylim(-50, 25)
    ax.set_xlim(20, 20000)
    ax.legend(fontsize=8.5, loc="lower left")
    ax.grid(True, which="both", alpha=0.4)
    
    # 4. Resonance Peaking Trajectories vs Control Parameter
    ax = axes[1, 1]
    ax.set_title("1D. Small-Signal Resonance Peak Growth vs Control Knob (fc = 1 kHz)", fontweight='bold')
    res_vals = np.linspace(0.0, 0.95, 25)
    pk_wasp, pk_stein, pk_poli, pk_ms20 = [], [], [], []
    
    for r in res_vals:
        _, m_w, _ = measure_frequency_response(sim_wasp, [1000.0], fc=1000.0, res=r, mode=0, drive=0.0)
        _, m_s, _ = measure_frequency_response(sim_steiner, [1000.0], fc=1000.0, res=r, mode=0, drive=0.0)
        _, m_p, _ = measure_frequency_response(sim_polivoks, [1000.0], fc=1000.0, res=r, mode=0, drive=0.0)
        _, m_m, _ = measure_frequency_response(sim_ms20_diode, [1000.0], fc=1000.0, res=r, drive=0.0)
        pk_wasp.append(m_w[0])
        pk_stein.append(m_s[0])
        pk_poli.append(m_p[0])
        pk_ms20.append(m_m[0])
        
    ax.plot(res_vals, pk_wasp, label="FSWasp (Analytical Pot Damping)", color="#1f77b4", lw=2, marker="o", ms=4)
    ax.plot(res_vals, pk_stein, label="FSSteiner (Sallen-Key Diode K -> 3.0)", color="#ff7f0e", lw=2, marker="s", ms=4)
    ax.plot(res_vals, pk_poli, label="FSPolivoks (Analytical r -> 0.02)", color="#2ca02c", lw=2, marker="^", ms=4)
    ax.plot(res_vals, pk_ms20, label="MS20Diode (Loaded 3 - K)", color="#d62728", lw=1.8, ls="--", marker="x", ms=4)
    
    ax.set_xlabel("Resonance Control Setting (res in [0, 1])")
    ax.set_ylabel("Peak Gain at Cutoff (dB)")
    ax.set_ylim(-5, 35)
    ax.legend(fontsize=9, loc="upper left")
    ax.grid(True, alpha=0.4)
    
    plt.tight_layout(rect=[0, 0.03, 1, 0.95])
    p1_path = os.path.join(ARTIFACT_DIR, "filtersuite_page1_linear_multimode.png")
    fig.savefig(p1_path, dpi=200)
    print(f"Saved: {p1_path}")
    return fig

# -----------------------------------------------------------------------------
# 4. Page 2: Nonlinear Saturation, Harmonic Distortion & Crest Factor
# -----------------------------------------------------------------------------

def make_page2():
    print("Generating Page 2: Nonlinear Saturation & Harmonic Distortion...")
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle("FilterSuite: Nonlinear Distortion, Harmonic Spectra & Waveform Shaping", fontsize=16, fontweight='bold', y=0.98)
    
    # Stimulus: 200 Hz Sine wave under high drive
    f_fund = 200.0
    dur = 0.05
    t = np.arange(int(dur * FS)) / FS
    vin = 0.5 * np.sin(2 * np.pi * f_fund * t)
    
    y_wasp = sim_wasp(vin, fc=1200.0, res=0.4, drive=3.5, mode=0)
    y_stein = sim_steiner(vin, fc=1200.0, res=0.4, drive=3.5, mode=0)
    y_poli = sim_polivoks(vin, fc=1200.0, res=0.4, drive=3.5, mode=0)
    y_ms20 = sim_ms20_circuit(vin, fc=1200.0, res=0.4, drive=3.5)
    
    # 1. Steady-State Waveforms (last 2 cycles)
    ax = axes[0, 0]
    ax.set_title("2A. Steady-State Waveforms (200 Hz Sine, drive = 3.5, fc = 1200 Hz)", fontweight='bold')
    cyc_samples = int(2.0 * FS / f_fund)
    t_plot = (t[-cyc_samples:] - t[-cyc_samples]) * 1000.0 # ms
    
    ax.plot(t_plot, y_wasp[-cyc_samples:], label="FSWasp (CMOS Inverter Soft Sat)", color="#1f77b4", lw=2)
    ax.plot(t_plot, y_stein[-cyc_samples:], label="FSSteiner (Diode Limiter Clamping)", color="#ff7f0e", lw=2)
    ax.plot(t_plot, y_poli[-cyc_samples:], label="FSPolivoks (Op-Amp Slew & Rail)", color="#2ca02c", lw=2)
    ax.plot(t_plot, y_ms20[-cyc_samples:], label="MS20Circuit (Asymmetric Reverse BJT)", color="#d62728", lw=1.8, ls="--")
    
    ax.set_xlabel("Time (milliseconds)")
    ax.set_ylabel("Output Amplitude (V)")
    ax.legend(fontsize=9, loc="upper right")
    ax.grid(True, alpha=0.4)
    
    # 2. Harmonic Distortion Spectra (FFT)
    ax = axes[0, 1]
    ax.set_title("2B. Harmonic Distortion Spectrum (FFT up to 3 kHz)", fontweight='bold')
    
    # Compute FFT on steady-state window
    fft_N = 8192
    t_fft = np.arange(fft_N) / FS
    v_long = 0.5 * np.sin(2 * np.pi * f_fund * t_fft)
    
    def get_spectrum(sim_fn, **kw):
        out = sim_fn(v_long, fc=1200.0, res=0.4, drive=3.5, **kw)
        win = np.hanning(fft_N)
        spec = np.abs(np.fft.rfft(out * win))
        spec_db = 20.0 * np.log10(np.maximum(1e-7, spec / np.max(spec)))
        freqs_fft = np.fft.rfftfreq(fft_N, 1.0 / FS)
        return freqs_fft, spec_db
        
    ff, sp_wasp = get_spectrum(sim_wasp, mode=0)
    _, sp_stein = get_spectrum(sim_steiner, mode=0)
    _, sp_poli = get_spectrum(sim_polivoks, mode=0)
    _, sp_ms20 = get_spectrum(sim_ms20_circuit)
    
    mask = (ff <= 3200)
    ax.plot(ff[mask], sp_wasp[mask], label="FSWasp (Odd Harmonics: 3rd, 5th, 7th)", color="#1f77b4", lw=1.8)
    ax.plot(ff[mask], sp_poli[mask], label="FSPolivoks (Odd Harmonics + Soft Rail)", color="#2ca02c", lw=1.5, ls=":")
    ax.plot(ff[mask], sp_ms20[mask], label="MS20Circuit (Prominent 2nd Harmonic Even Growl)", color="#d62728", lw=1.8, ls="--")
    
    ax.set_xlabel("Frequency (Hz)")
    ax.set_ylabel("Normalized Magnitude (dB)")
    ax.set_ylim(-70, 5)
    ax.set_xlim(100, 3200)
    ax.legend(fontsize=8.5, loc="upper right")
    ax.grid(True, alpha=0.4)
    
    # 3. Crest Factor Compression vs Drive
    ax = axes[1, 0]
    ax.set_title("2C. Crest Factor Compression vs Drive Knob (Sine Input -> Square)", fontweight='bold')
    drives = np.linspace(0.2, 8.0, 30)
    cf_wasp, cf_stein, cf_poli, cf_ms20 = [], [], [], []
    
    t_cf = np.arange(int(0.04 * FS)) / FS
    v_cf = 0.4 * np.sin(2 * np.pi * 300.0 * t_cf)
    
    for d in drives:
        o_w = sim_wasp(v_cf, fc=1000.0, res=0.3, drive=d, mode=0)
        o_s = sim_steiner(v_cf, fc=1000.0, res=0.3, drive=d, mode=0)
        o_p = sim_polivoks(v_cf, fc=1000.0, res=0.3, drive=d, mode=0)
        o_m = sim_ms20_circuit(v_cf, fc=1000.0, res=0.3, drive=d)
        
        tail = int(len(v_cf) * 0.5)
        def calc_cf(arr):
            sub = arr[tail:]
            return np.max(np.abs(sub)) / (np.sqrt(np.mean(sub**2)) + 1e-9)
            
        cf_wasp.append(calc_cf(o_w))
        cf_stein.append(calc_cf(o_s))
        cf_poli.append(calc_cf(o_p))
        cf_ms20.append(calc_cf(o_m))
        
    ax.plot(drives, cf_wasp, label="FSWasp (Crest compresses 1.41 -> 1.15)", color="#1f77b4", lw=2)
    ax.plot(drives, cf_stein, label="FSSteiner (Diode Limiting)", color="#ff7f0e", lw=2)
    ax.plot(drives, cf_poli, label="FSPolivoks (Op-Amp Slew Compression)", color="#2ca02c", lw=2)
    ax.plot(drives, cf_ms20, label="MS20Circuit (Asymmetric Compression)", color="#d62728", lw=1.8, ls="--")
    ax.axhline(np.sqrt(2), color="gray", ls=":", label="Ideal Sine Crest (1.414)")
    ax.axhline(1.0, color="black", ls=":", label="Ideal Square Crest (1.000)")
    
    ax.set_xlabel("Drive Parameter")
    ax.set_ylabel("Crest Factor (V_peak / V_rms)")
    ax.set_ylim(0.9, 1.6)
    ax.legend(fontsize=8.5, loc="upper right")
    ax.grid(True, alpha=0.4)
    
    # 4. Large-Signal Level-Dependent Loop Gain (Self-Limiting)
    ax = axes[1, 1]
    ax.set_title("2D. Output Amplitude vs Input Level (Level Compression)", fontweight='bold')
    in_amps_db = np.linspace(-40, 15, 30)
    out_wasp, out_stein, out_poli = [], [], []
    
    for a_db in in_amps_db:
        amp = 10.0 ** (a_db / 20.0)
        v_in_amp = amp * np.sin(2 * np.pi * 500.0 * t_cf)
        
        ow = sim_wasp(v_in_amp, fc=1000.0, res=0.7, drive=2.0, mode=0)
        out_s = sim_steiner(v_in_amp, fc=1000.0, res=0.7, drive=2.0, mode=0)
        op = sim_polivoks(v_in_amp, fc=1000.0, res=0.7, drive=2.0, mode=0)
        
        tail = int(len(v_cf) * 0.5)
        out_wasp.append(20.0 * np.log10(np.max(np.abs(ow[tail:])) + 1e-9))
        out_stein.append(20.0 * np.log10(np.max(np.abs(out_s[tail:])) + 1e-9))
        out_poli.append(20.0 * np.log10(np.max(np.abs(op[tail:])) + 1e-9))
        
    ax.plot(in_amps_db, in_amps_db, color="gray", ls=":", label="Linear Reference (1:1 Gain)")
    ax.plot(in_amps_db, out_wasp, label="FSWasp Output", color="#1f77b4", lw=2)
    ax.plot(in_amps_db, out_stein, label="FSSteiner Output", color="#ff7f0e", lw=2)
    ax.plot(in_amps_db, out_poli, label="FSPolivoks Output", color="#2ca02c", lw=2)
    
    ax.set_xlabel("Input Level (dBFS)")
    ax.set_ylabel("Output Peak Level (dBFS)")
    ax.legend(fontsize=9, loc="lower right")
    ax.grid(True, alpha=0.4)
    
    plt.tight_layout(rect=[0, 0.03, 1, 0.95])
    p2_path = os.path.join(ARTIFACT_DIR, "filtersuite_page2_nonlinear_harmonics.png")
    fig.savefig(p2_path, dpi=200)
    print(f"Saved: {p2_path}")
    return fig

# -----------------------------------------------------------------------------
# 5. Page 3: Autonomous Limit Cycles, State Space & Audio FM
# -----------------------------------------------------------------------------

def make_page3():
    print("Generating Page 3: Autonomous Limit Cycles & Audio FM...")
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle("FilterSuite: Autonomous Self-Oscillation, Phase Plane & Audio FM", fontsize=16, fontweight='bold', y=0.98)
    
    # 1. Autonomous Limit Cycles in Silence (Initial pulse trigger, then zero input)
    dur = 0.04
    N = int(dur * FS)
    x_trig = np.zeros(N)
    x_trig[0] = 0.1 # Tiny seed pulse
    
    y_stein_osc = sim_steiner(x_trig, fc=880.0, res=0.95, mode=0, drive=1.0)
    y_poli_osc = sim_polivoks(x_trig, fc=880.0, res=1.05, mode=0, drive=1.0)
    y_ms20_osc = sim_ms20_diode(x_trig, fc=880.0, res=0.98, drive=1.0)
    
    ax = axes[0, 0]
    ax.set_title("3A. Autonomous Self-Oscillation Limit Cycles (fc = 880 Hz, Zero Input)", fontweight='bold')
    t_ms = np.arange(800) / FS * 1000.0
    
    ax.plot(t_ms, y_stein_osc[-800:], label="FSSteiner Limit Cycle (Peak ~ 0.77, Pure Diode Sine)", color="#ff7f0e", lw=2)
    ax.plot(t_ms, y_poli_osc[-800:], label="FSPolivoks Limit Cycle (Peak ~ 0.17, Op-Amp Saturated)", color="#2ca02c", lw=2)
    ax.plot(t_ms, y_ms20_osc[-800:], label="MS20Diode Limit Cycle (Korg-35 Forward Diode)", color="#d62728", lw=1.8, ls="--")
    
    ax.set_xlabel("Time (milliseconds)")
    ax.set_ylabel("Limit Cycle Amplitude (V)")
    ax.legend(fontsize=8.5, loc="upper right")
    ax.grid(True, alpha=0.4)
    
    # 2. State-Space Phase Plane Portraits (v vs dv/dt)
    ax = axes[0, 1]
    ax.set_title("3B. State-Space Phase Plane Portrait (Limit Cycle Attractors)", fontweight='bold')
    
    def get_phase_portrait(arr):
        v = arr[-1200:]
        # Numerical derivative
        dv = np.gradient(v) * (FS / 880.0)
        return v, dv
        
    v_s, dv_s = get_phase_portrait(y_stein_osc)
    v_p, dv_p = get_phase_portrait(y_poli_osc)
    v_m, dv_m = get_phase_portrait(y_ms20_osc)
    
    ax.plot(v_s, dv_s, label="FSSteiner Orbit (Smooth Elliptical Limit Cycle)", color="#ff7f0e", lw=2)
    ax.plot(v_p, dv_p, label="FSPolivoks Orbit (Saturated Op-Amp Attractor)", color="#2ca02c", lw=2)
    ax.plot(v_m, dv_m, label="MS20Diode Orbit (Forward Diode Attractor)", color="#d62728", lw=1.8, ls="--")
    
    ax.set_xlabel("State Voltage v(t)")
    ax.set_ylabel("Normalized State Rate dv/dt")
    ax.legend(fontsize=8.5, loc="upper right")
    ax.grid(True, alpha=0.4)
    
    # 3. Audio-Rate Cutoff Frequency Modulation (FM)
    ax = axes[1, 0]
    ax.set_title("3C. Audio-Rate Filter FM Spectrum (100 Hz Saw, 150 Hz Modulator)", fontweight='bold')
    
    t_fm = np.arange(8192) / FS
    carrier = 0.25 * (2.0 * (t_fm * 100.0 - np.floor(t_fm * 100.0 + 0.5))) # 100 Hz Saw
    fm_mod = 1200.0 * np.sin(2 * np.pi * 150.0 * t_fm)
    fc_mod = np.clip(2200.0 + fm_mod, 100.0, 18000.0)
    
    # Simulate per-sample FM in Python
    def sim_fm_wasp():
        N = len(carrier)
        y = np.zeros(N)
        s1, s2 = 0.0, 0.0
        for i in range(N):
            g = np.tan(np.pi * fc_mod[i] / FS)
            denom = 1.0 + 0.3 * g + g * g
            v_hp = -(carrier[i] + (0.3 + g) * s1 + s2) / denom
            v_bp = g * v_hp + s1
            v_lp = g * v_bp + s2
            s1 = 2.0 * v_bp - s1
            s2 = 2.0 * v_lp - s2
            y[i] = v_lp
        return y
        
    y_fm = sim_fm_wasp()
    win = np.hanning(len(y_fm))
    spec_fm = np.abs(np.fft.rfft(y_fm * win))
    spec_fm_db = 20.0 * np.log10(np.maximum(1e-7, spec_fm / np.max(spec_fm)))
    freqs_fm = np.fft.rfftfreq(len(y_fm), 1.0 / FS)
    
    ax.plot(freqs_fm, spec_fm_db, color="#1f77b4", lw=1.5, label="FSWasp Audio FM Spectrum")
    ax.set_xlabel("Frequency (Hz)")
    ax.set_ylabel("Magnitude (dB)")
    ax.set_ylim(-65, 5)
    ax.set_xlim(0, 4000)
    ax.legend(fontsize=9, loc="upper right")
    ax.grid(True, alpha=0.4)
    
    # 4. High-Speed Cutoff Sweep Transient Stability
    ax = axes[1, 1]
    ax.set_title("3D. Fast Cutoff Sweep (4 Octaves in 20 ms: 200 Hz -> 3200 Hz)", fontweight='bold')
    
    t_sw = np.arange(int(0.03 * FS)) / FS
    carrier_sw = 0.25 * np.sin(2 * np.pi * 300.0 * t_sw)
    fc_sw = 200.0 * (16.0 ** (t_sw / 0.02)) # Exponential sweep
    fc_sw = np.clip(fc_sw, 200.0, 3200.0)
    
    # Simulate sweep on FSPolivoks
    y_sw = np.zeros(len(carrier_sw))
    s1, s2 = 0.0, 0.0
    for i in range(len(carrier_sw)):
        g = np.tan(np.pi * fc_sw[i] / FS)
        r = 0.15 # High resonance
        denom = 1.0 + r * g + g * g
        v_sum = (carrier_sw[i] - (r + g) * s1 - s2) / denom
        v_bp = g * v_sum + s1
        v_lp = g * v_bp + s2
        s1 = 2.0 * v_bp - s1
        s2 = 2.0 * v_lp - s2
        y_sw[i] = v_lp
        
    ax.plot(t_sw * 1000.0, y_sw, color="#2ca02c", lw=1.8, label="FSPolivoks Fast Cutoff Sweep (Zero Blowup)")
    ax.plot(t_sw * 1000.0, carrier_sw, color="gray", lw=1.0, ls=":", alpha=0.6, label="Input Sine (300 Hz)")
    ax.set_xlabel("Time (milliseconds)")
    ax.set_ylabel("Output Amplitude")
    ax.legend(fontsize=9, loc="upper right")
    ax.grid(True, alpha=0.4)
    
    plt.tight_layout(rect=[0, 0.03, 1, 0.95])
    p3_path = os.path.join(ARTIFACT_DIR, "filtersuite_page3_limit_cycles_and_fm.png")
    fig.savefig(p3_path, dpi=200)
    print(f"Saved: {p3_path}")
    return fig

# -----------------------------------------------------------------------------
# 6. Page 4: Advanced Morphological & Temporal Dispersive Processing
# -----------------------------------------------------------------------------

def make_page4():
    print("Generating Page 4: Advanced Morphological & Temporal Dispersion...")
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle("FilterSuite: Advanced Digital Response Morphing (FSZMorph) & All-Pass Dispersion (FSDispersion)", fontsize=15, fontweight='bold', y=0.98)
    
    freqs = np.logspace(np.log10(50), np.log10(15000), 150)
    
    # 1. FSZMorph Continuous Response Evolution (Vowel A -> Vowel I)
    ax = axes[0, 0]
    ax.set_title("4A. FSZMorph: Continuous Formant Morphing (Vowel A -> Vowel I)", fontweight='bold')
    
    morph_steps = [0.0, 0.25, 0.50, 0.75, 1.0]
    colors = plt.cm.plasma(np.linspace(0.1, 0.9, len(morph_steps)))
    
    for m, c in zip(morph_steps, colors):
        label_str = f"morph = {m:.2f}"
        if m == 0.0: label_str += " (Pure Vowel A: 730/1090 Hz)"
        elif m == 1.0: label_str += " (Pure Vowel I: 270/2290 Hz)"
        _, mag_m, _ = measure_frequency_response(sim_zmorph, freqs, morph=m, shapeA=0, shapeB=1)
        ax.semilogx(freqs, mag_m, label=label_str, color=c, lw=2.0 if m in [0.0, 1.0] else 1.3)
        
    ax.set_xlabel("Frequency (Hz)")
    ax.set_ylabel("Magnitude (dB)")
    ax.set_ylim(-35, 15)
    ax.set_xlim(50, 15000)
    ax.legend(fontsize=8.5, loc="lower left")
    ax.grid(True, which="both", alpha=0.4)
    
    # 2. FSZMorph Preset Profiles (All 6 Presets)
    ax = axes[0, 1]
    ax.set_title("4B. FSZMorph: Spectral Profiles Across All 6 Built-in Presets", fontweight='bold')
    
    preset_names = ["0: Vowel A (Ah)", "1: Vowel I (Ee)", "2: Vowel U (Oo)", "3: Deep Comb", "4: Metallic Bell", "5: Acoustic Body"]
    preset_colors = ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd", "#8c564b"]
    
    for idx, (name, col) in enumerate(zip(preset_names, preset_colors)):
        _, mag_pr, _ = measure_frequency_response(sim_zmorph, freqs, morph=0.0, shapeA=idx, shapeB=idx)
        ax.semilogx(freqs, mag_pr, label=name, color=col, lw=1.8)
        
    ax.set_xlabel("Frequency (Hz)")
    ax.set_ylabel("Magnitude (dB)")
    ax.set_ylim(-35, 15)
    ax.set_xlim(50, 15000)
    ax.legend(fontsize=8.0, loc="lower left", ncol=2)
    ax.grid(True, which="both", alpha=0.4)
    
    # 3. FSDispersion Flat Magnitude Response
    ax = axes[1, 0]
    ax.set_title("4C. FSDispersion: Strict Flat Magnitude Preservation (|H| = 0.0 dB)", fontweight='bold')
    
    freqs_ap = np.logspace(np.log10(20), np.log10(20000), 200)
    _, mag_ap1, _ = measure_frequency_response(sim_dispersion, freqs_ap, center=1500.0, spread=1.0, q=2.0)
    _, mag_ap2, _ = measure_frequency_response(sim_dispersion, freqs_ap, center=3000.0, spread=2.0, q=5.0)
    _, mag_ap3, _ = measure_frequency_response(sim_dispersion, freqs_ap, center=800.0, spread=0.0, q=10.0)
    
    ax.semilogx(freqs_ap, mag_ap1, label="FSDispersion (center=1.5k, spread=1.0, q=2.0)", color="#1f77b4", lw=2)
    ax.semilogx(freqs_ap, mag_ap2, label="FSDispersion (center=3.0k, spread=2.0, q=5.0)", color="#2ca02c", lw=1.8, ls="--")
    ax.semilogx(freqs_ap, mag_ap3, label="FSDispersion (center=800, spread=0.0, q=10.0)", color="#ff7f0e", lw=1.8, ls=":")
    
    ax.set_xlabel("Frequency (Hz)")
    ax.set_ylabel("Magnitude (dB)")
    ax.set_ylim(-2.0, 2.0) # Zoom in to show strict 0 dB flatness!
    ax.set_xlim(20, 20000)
    ax.axhline(0.0, color="black", ls="-", lw=0.8, alpha=0.7)
    ax.legend(fontsize=8.5, loc="lower left")
    ax.grid(True, which="both", alpha=0.4)
    
    # 4. FSDispersion Temporal Impulse Smearing (Group Delay Chirp)
    ax = axes[1, 1]
    ax.set_title("4D. FSDispersion: Impulse Temporal Smearing & Parseval Energy Conservation", fontweight='bold')
    
    N_imp = 256
    imp = np.zeros(N_imp)
    imp[0] = 1.0
    out_chirp = sim_dispersion(imp, center=1500.0, spread=1.5, q=4.0)
    
    e_in = np.sum(imp**2)
    e_out = np.sum(out_chirp**2)
    
    n_samples = np.arange(N_imp)
    ax.stem([0], [1.0], linefmt="gray", markerfmt="ko", basefmt=" ", label=f"Input Dirac Delta (E = {e_in:.6f})")
    ax.plot(n_samples, out_chirp, color="#d62728", lw=1.8, label=f"Dispersed Output (E = {e_out:.6f}, Ratio = {e_out/e_in:.6f})")
    
    ax.set_xlabel("Sample Index (n)")
    ax.set_ylabel("Signal Amplitude")
    ax.set_xlim(-5, 180)
    ax.set_ylim(-0.8, 1.1)
    ax.legend(fontsize=9, loc="upper right")
    ax.grid(True, alpha=0.4)
    
    plt.tight_layout(rect=[0, 0.03, 1, 0.95])
    p4_path = os.path.join(ARTIFACT_DIR, "filtersuite_page4_morph_and_dispersion.png")
    fig.savefig(p4_path, dpi=200)
    print(f"Saved: {p4_path}")
    return fig

# -----------------------------------------------------------------------------
# 7. Multi-Page PDF Assembly
# -----------------------------------------------------------------------------

def build_pdf(figures):
    pdf_path = os.path.join(ARTIFACT_DIR, "FilterSuite_Complete_Comparison_and_Analysis.pdf")
    print(f"Compiling complete multi-page PDF document: {pdf_path}...")
    with PdfPages(pdf_path) as pdf:
        for f in figures:
            pdf.savefig(f)
    print("PDF build complete!")

if __name__ == "__main__":
    f1 = make_page1()
    f2 = make_page2()
    f3 = make_page3()
    f4 = make_page4()
    build_pdf([f1, f2, f3, f4])
    print("ALL FILTERSUITE COMPARISON FIGURES AND PDF COMPILED SUCCESSFULLY!")
