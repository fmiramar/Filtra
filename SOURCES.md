# MS-20 Filters: Research Sources & Implementation Decisions

## 1. Primary Circuit Reference
* **Timothy E. Stinchcombe (2006, minor corrections 2009)**, *A Study of the Korg MS10 & MS20 Filters*, Sections 2.2 and 7.
  * URL: https://www.timstinchcombe.co.uk/synth/MS20_study.pdf
  * Findings:
    * The early Korg-35 filter is a Sallen-Key topology with strong mutual loading between the first and second RC stages.
    * Linear Low-Pass transfer function with loading and equal-component simplification ($u = s/\omega_0$, $\omega_0 = 1/(RC)$, $K = k_1 k_2$):
      $$H_{LP}(s) = \frac{k_1}{u^2 + (3 - K)u + 1}$$
      DC passband gain is $k_1 = 1$, high-frequency roll-off asymptote is 12 dB/octave.
      Self-oscillation occurs at $K = 3$ (not $K = 2$ as in buffered Sallen-Key filters).
    * Historical MS-20 High-Pass topology: Korg grounded the LP input and lifted capacitor $C_2$ off ground to inject the input.
    * High-Pass transfer function from Kirchhoff nodal analysis:
      $$H_{HP}(s) = \frac{k_1 (u^2 + 2u)}{u^2 + (3 - K)u + 1}$$
      At DC ($s \to 0$), $H_{HP}(s) \sim 2 k_1 \frac{s}{\omega_0}$, yielding a +6 dB/octave slope (single zero at DC, single finite zero at $s = -2\omega_0$). At high frequencies ($s \to \infty$), $H_{HP}(s) \to k_1 = 1$ (flat passband). Denominator remains 2nd-order with resonance controlled by $(3 - K)$.

## 2. Discretization Method
* **Bilinear Transform (Prewarped Tustin)**:
  * Continuous analog reference frequency prewarping:
    $$\omega_a = 2 f_s \tan\left(\frac{\pi f_c}{f_s}\right) \implies c = \frac{1}{\tan(\pi f_c / f_s)}$$
  * Substitution: $u = c \frac{1 - z^{-1}}{1 + z^{-1}}$.
  * Realized as a Transposed Direct Form II biquad in `double` precision with subnormal flushing (`zapgremlins`).
  * Resonance parameter mapping: $K = \text{res} \times 2.95$ for $\text{res} \in [0, 1]$. Maximum $Q = 1 / (3 - 2.95) = 20.0$.
    Clamped strictly below $K = 3$ to guarantee bounded linear stability.

## 4. Topology-Preserving Zero-Delay Model (`MS20TPT`)
* **Continuous State-Space Representation with Mutual Stage Loading**:
  * State vector $\mathbf{v} = \begin{pmatrix} v_{C1} \\ v_{C2} \end{pmatrix}$ representing physical capacitor voltages.
  * System matrix $A_0 = \begin{pmatrix} -2 & 2K - 1 \\ -1 & K - 1 \end{pmatrix}$.
  * Zero-delay feedback matrix $M = (I - g A_0)$ where $g = \tan(\pi f_c / f_s)$.
  * Determinant $\det(M) = g^2 + (3 - K) g + 1$.
* **Loaded vs. Buffered Formulation**:
  * **Loaded Model (Implemented in `MS20SK` and `MS20TPT`)**: The second RC stage directly loads the first node, giving damping factor $(3 - K)$ and critical self-oscillation threshold $K = 3.0$.
  * **Buffered Approximation (e.g. Will Pirkle AN-5 & AN-7A, Csound `k35_lpf`)**: Assumes ideal buffering between RC stages, giving damping factor $(2 - K)$ and critical self-oscillation threshold $K = 2.0$.
  * By formulating `MS20TPT` with the exact loaded state space, `MS20SK` and `MS20TPT` share the identical underlying physical circuit model and match to within $< 10^{-14}$ at static linear settings.
* **Why Model B (`MS20TPT`) exists alongside Model A (`MS20SK`)**:
  * In the linear, time-invariant case, both models converge to the same bilinear transfer function.
  * However, `MS20TPT` preserves the continuous topology and maintains states as physical capacitor voltages ($v_{C1}, v_{C2}$).
  * This structure enables stable, artifact-free parameter modulation and provides the correct physical insertion point for the early Korg-35 nonlinear diode limiter in Milestone 3.

## 5. Milestone 3: Nonlinear Early Korg-35 Forward Amplifier Diode Model (`MS20Diode`)
* **Forward Amplifier Diode Limiting (Stinchcombe §5)**:
  * In the early Korg-35 filter, the nonlinear elements are anti-parallel back-to-back diodes inside the local feedback path of the active forward amplifier, NOT in the resonance feedback path (which belongs to the later OTA revision).
  * As signal level increases, diode conduction reduces the forward amplifier's incremental gain from its nominal value down to unity.
  * In `MS20Diode`, the algebraic soft limiter $f(u) = \frac{u}{\sqrt{1 + (\text{drive} \cdot u)^2}}$ (and its counterpart $\tanh$) models this progressive gain reduction.
  * Because the nonlinearity depends directly on node $V_3$, the instantaneous zero-delay feedback loop collapses into a 1-D scalar equation:
    $$(1 + 3g + g^2) u - g K f(u) - p = 0$$
    which is solved per-sample via a 3-iteration Newton-Raphson solver to machine precision.
  * At small levels, $f(u) \approx u$, matching `MS20TPT` and `MS20SK`.
  * At high resonance ($K \ge 3.0$), the nonlinear gain reduction stabilizes the loop, producing an autonomous, bounded limit-cycle sinusoidal self-oscillation without digital divergence.

## 6. Milestone 4: Later Revision MS-20 Dual OTA Filter (`MS20OTA`)
* **KLM-307 Daughterboard Topology (Stinchcombe §§2.1 & 5)**:
  * Based on dual LM13600 Operational Transconductance Amplifiers (OTAs).
  * **Inter-Stage Isolation:** An active unity buffer sits between the first and second OTA integrator stages. Therefore, mutual inter-stage loading is absent.
  * **Critical Gain:** Damping is $(2 - K)$ rather than $(3 - K)$. Linear self-oscillation begins at $K = 2.0$ (instead of $K = 3.0$).
  * **Resonance Feedback Diode Placement:** The clipping diodes are located in the *resonance feedback amplifier*, not in the forward signal path.
  * **Sonic Character:** Because the forward path is linear, passband audio signals do not suffer distortion when drive or input levels increase. Clipping occurs exclusively on resonant peak frequencies circulating through the feedback network, yielding a cleaner, liquid, "singing" resonance.
  * **1-D Zero-Delay Resolution:** Feedback voltage $v_{fb} = V_2 - V_o$ is resolved via:
    $$(1 + g)^2 v_{fb} - g K f(v_{fb}) - p = 0$$

## 7. Milestone E: Transistor / Circuit Modeling (`MS20Circuit`)
* **Reverse-Saturation BJT Operation (Stinchcombe §3.1)**:
  * In the vintage Korg-35 hybrid module, the voltage-controlled resistors are bipolar junction transistors ($Q_1, Q_2$) operated backward in reverse saturation mode.
  * Unlike symmetric clippers or ideal resistors, the transport factors $\alpha_F$ (forward gain $\approx 0.99$) and $\alpha_R$ (reverse gain $\approx 0.25$) are strongly asymmetric.
  * This asymmetry introduces a non-zero second-order term $\left(\frac{1}{2} - \alpha_R\right) \nu^2$ in the normalized V-I characteristic:
    $$\phi(\nu) = \frac{1 - e^{-\nu}}{\alpha_R + (1 - \alpha_R) e^{-\nu}} \approx \nu + \left(\frac{1}{2} - \alpha_R\right)\nu^2 + \mathcal{O}(\nu^3)$$
  * This quadratic term generates **even harmonics (prominent 2nd harmonic $2f$)**, reproducing the distinctively aggressive, raspy bite of early Korg-35 hardware under hot drive.
* **2x2 Coupled Nonlinear MNA Formulation**:
  * Kirchhoff's current law at Node 1 and Node 2 coupled with trapezoidal capacitor integration yields the 2x2 nonlinear system:
    $$F_1(V_1, V_2) = V_1 + V_2 - V_{ref} - K f(V_2) - g \phi(V_{in1} - V_1) - (s_1 + s_2) = 0$$
    $$F_2(V_1, V_2) = V_2 - V_{ref} - g \phi(V_1 - V_2) - s_2 = 0$$
  * When linearized ($\phi(u) = u, f(u) = u$), the Jacobian determinant is analytically exact:
    $$\det(J) = g^2 + (3 - K)g + 1$$
    proving that mutual RC stage loading $(3 - K)$ emerges directly and naturally from the nodal equations.
  * Solved simultaneously per sample via 3-iteration 2x2 Newton-Raphson iteration with warm-started state vectors.

## 8. Option A: Release Polish, Quark Packaging & Audio-Rate FM
* **SuperCollider Quark Definition (`MS20Filters.quark`)**:
  * Configured package metadata for installation through the official SuperCollider Quark manager.
* **Sample-Accurate Audio-Rate Modulation (`.ar`)**:
  * All five UGens (`MS20SK`, `MS20TPT`, `MS20Diode`, `MS20OTA`, `MS20Circuit`) implement dedicated audio-rate calculation loops (`_next_*_a`) when `INRATE(1) == calc_FullRate`.
  * For TPT, Diode, OTA, and Circuit models, per-sample integrator coefficient updates eliminate block-boundary stepping, unlocking clean, artifact-free audio-rate filter FM.
* **Unified Audition & Visual Studio**:
  * Standalone audition scripts (`MS20_Complete_Audition.scd`, `MS20Circuit_demo.scd`) and interactive real-time visual GUI (`MS20_Audition_GUI.scd` with integrated `FreqScopeView` and `ScopeView`).

## 9. License Findings
* The mathematical equations and circuit transfer functions derived from Stinchcombe and Zavalishin are public scientific analysis.
* SuperCollider plugin implementation uses original clean-room C++ and SuperCollider classes under GPL-3.0-or-later.

## 10. Tier 5: 2x Polyphase Half-Band Oversampling (`MS20Oversampler.hpp`)
* **Aliasing in Extreme Overdrive & Audio-Rate FM**:
  * In non-linear virtual analog filters, diode clipping and BJT saturation generate high-order harmonics that extend beyond the Nyquist limit ($f_s / 2$).
  * In 1x baseband processing at 44.1 kHz, harmonic components above 22.05 kHz reflect back into the audible spectrum as discordant inharmonic sidebands (e.g. the 9th harmonic of 3.5 kHz at 31.5 kHz aliases to 12.6 kHz).
* **2-Path Polyphase Allpass Filter Architecture**:
  * Implemented an internal 2x oversampling engine decomposing a half-band lowpass filter:
    $$H(z) = \frac{1}{2}\left(A_0(z^2) + z^{-1} A_1(z^2)\right)$$
  * Allpass coefficient set derived from optimal elliptic half-band decomposition:
    * Path 0: $c_0 = 0.07986642623635751, c_2 = 0.5453986507421008$
    * Path 1: $c_1 = 0.28382934487410993, c_3 = 0.8344117769868580$
  * **Performance & Purity:**
    * Rejection: $> 70\text{ dB}$ stopband attenuation across the entire mirror band (measured $> 90\text{ dB}$ on foldover harmonics in `test_oversampling.scd`).
    * Passband ripple: $< 0.0005\text{ dB}$ from 20 Hz to 20 kHz.
    * Computational complexity: only 8 multiplications per sample total (4 for upsampling, 4 for decimation), with minimal phase delay and zero block-buffering latency.
  * Supported optionally via `oversample: 1` across all three nonlinear models (`MS20Diode`, `MS20Circuit`, `MS20OTA`).


## 11. Milestone 1: EDP Wasp State-Variable VCF (`FSWasp` Stage W1 & W2)
* **Primary Reference:**
  * L. Köper, M. Holters, F. Esqueda, and J. D. Parker (2022), *A Virtual Analog Model of the EDP Wasp VCF*, Proceedings of the 25th International Conference on Digital Audio Effects (DAFx20in22), Vienna, Austria, September 2022.
* **Circuit Topology & Modeled Revision:**
  * Modeled after the Doepfer-derived circuit revision analyzed by Köper et al., featuring CA3080 Operational Transconductance Amplifiers (OTAs) and CD4069 unbuffered CMOS inverters.
  * Node Mapping:
    * Summing node: Inverter IC1 (CD4069) acts as summing amplifier providing the High-Pass (HP) output.
    * Integrator 1: OTA IC2 + Inverter IC3 (with feedback capacitor $C_3 = 330\text{ pF}$) integrates $v_{HP}$, providing the Band-Pass (BP) output ($v_{IC3}$).
    * Integrator 2: OTA IC4 + Inverter IC5 (with feedback capacitor $C_4 = 330\text{ pF}$) integrates $v_{BP}$, providing the Low-Pass (LP) output ($v_{IC5}$).
  * Resonance Potentiometer Network ($R_{res} = 50\text{ k}\Omega, R_{13} = 1\text{ M}\Omega, R_{14} = 1\text{ k}\Omega, R_{15} = 100\text{ k}\Omega, R_4 = 27\text{ k}\Omega, C_7 = 0.22\text{ }\mu\text{F}$):
    * Analytical damping:
      $$k_{res} = \frac{1}{Q} = \Re(H_1(j\omega_c)) + R_2 C_2 \omega_c$$
      where $R_2 C_2 = 27\text{ k}\Omega \times 100\text{ pF} = 2.7\text{ }\mu\text{s}$. Damping varies continuously from $\sim 0.96$ ($Q \approx 1.04$) down to $\sim 0.012$ ($Q \approx 84$).
* **Stage W1: Linear Small-Signal State-Variable Discretization:**
  * Topology-Preserving Transform (TPT / Trapezoidal) state equations:
    $$v_{HP} = -(v_{in} + (k_{res} + g) s_1 + s_2) / (1 + k_{res} g + g^2)$$
    $$v_{BP} = g v_{HP} + s_1$$
    $$v_{LP} = g v_{BP} + s_2$$
  * State update: $s_1[n+1] = 2 v_{BP} - s_1[n]$, $s_2[n+1] = 2 v_{LP} - s_2[n]$.
* **Stage W2: Circuit-Informed Nonlinear OTA & CMOS Model:**
  * OTA CA3080 differential input saturation:
    $$f_{ota}(x) = \frac{\tanh(\alpha x)}{\alpha}$$
  * CD4069 unbuffered CMOS inverter transfer function:
    $$f_{cmos}(x) = \frac{x}{\sqrt{1 + (\beta x)^2}}$$
    where $\alpha = \text{drive}$ and $\beta = 0.5 \cdot \text{drive}$.
  * Implicit 1-D scalar loop at summing node IC1:
    $$F(v_{HP}) = v_{HP} + f_{cmos}\left(v_{in} + k_{res} f_d(v_{BP}(v_{HP})) + v_{LP}(v_{HP})\right) = 0$$
    Monotonically increasing ($F'(v) \ge 1$), strictly guaranteed unique real root, solved in max 4 iterations via Newton-Raphson to machine precision ($< 10^{-6}$).
  * High-drive harmonic compression: higher drive compresses fundamental crest factor and produces authentic odd-order analog warmth.
  * Small-signal convergence: converges to Stage W1 linear model to within $< 10^{-7}$ for quiet signals.


## 12. Milestone 2: Steiner-Parker Multimode Diode VCF (`FSSteiner`)
* **Primary References:**
  * Nyle A. Steiner (1974), "Voltage-tunable active filter features low, high and bandpass modes", *Electronic Design*, Issue 25, Dec 6, 1974.
  * Yves Usson (2004), *Steiner VCF (2SC1583 + OPA revision)*, YuSynth Modular Synthesizer Project, http://yusynth.net/Modular/EN/STEINERVCF/index.html.
  * Yasunori Hirakawa / Osamu Hoshuyama circuit contributions (diode limiter in resonance feedback loop).
* **Circuit Topology & Multi-Input Injection:**
  * The Steiner-Parker VCF is a 2-pole Sallen-Key multimode filter where the conventional resistors are replaced by strings of forward-biased 1N4148 diodes acting as voltage-controlled variable resistors.
  * Unlike standard filters that take a single input and tap multiple output points, the Steiner-Parker filter has a **single active output** $v_{out}$ and selects modes by injecting the audio signal into distinct circuit nodes:
    * **Low-Pass (LP, mode = 0):** Injected at the input of the first diode resistance stage ($B_{open} = [-1, 0]^T$). Roll-off is $-12\text{ dB/octave}$ (2 poles, 0 transmission zeros).
    * **Band-Pass (BP, mode = 1):** Injected at the feedback capacitor node ($B_{open} = [2, 1]^T$). Center frequency peak with symmetric $+6\text{ dB/oct}$ low skirt and $-6\text{ dB/oct}$ high skirt.
    * **High-Pass (HP, mode = 2):** Injected at the second capacitor node ($B_{open} = [-1, -1]^T$). Passband gain at Nyquist is $0\text{ dB}$, with a $+6\text{ dB/octave}$ low-frequency roll-off due to the finite zero at $s = -2\omega_c$.
* **Continuous-Time Transfer Functions:**
  $$D(s) = s^2 + (3 - K) s + 1$$
  $$H_{LP}(s) = \frac{1}{s^2 + (3 - K) s + 1}$$
  $$H_{BP}(s) = \frac{s}{s^2 + (3 - K) s + 1}$$
  $$H_{HP}(s) = \frac{s^2 + 2s}{s^2 + (3 - K) s + 1}$$
* **Topology-Preserving Transform (TPT / ZDF) State-Space Discretization:**
  * Open-loop system matrix: $A_{open} = \begin{pmatrix} -2 & -1 \\ -1 & -1 \end{pmatrix}$.
  * Resolvent: $M_0 = (I - g A_{open})^{-1} = \frac{1}{g^2 + 3g + 1} \begin{pmatrix} 1 + g & -g \\ -g & 1 + 2g \end{pmatrix}$.
  * Feedback vector: $F = \begin{pmatrix} 2 \\ 1 \end{pmatrix}$, feedback scalar gain $\gamma = \frac{g}{g^2 + 3g + 1}$.
  * Instantaneous 1-D scalar loop:
    $$F(v_{out}) = v_{out} - v_{open} - \gamma \cdot K \cdot f_{nl}(v_{out}) = 0$$
  * Diode limiting across op-amp U2 feedback: $f_{nl}(v) = \frac{\tanh(\alpha v)}{\alpha}$ where $\alpha = \text{drive}$.
  * Solved in max 4 iterations via bounded Newton-Raphson iteration.
  * Self-oscillation: at $K \ge 3.0$ ($\text{res} \ge 0.83$), the diode limiter stabilizes the positive feedback loop into an autonomous, non-exploding sinusoidal limit cycle (measured peak $\approx 0.77$).


## 13. Milestone 3: Formanta Polivoks VCF (`FSPolivoks` Stages P1 & P2)
* **Primary References:**
  * Vladimir Kuzmin (1982), *Formanta Polivoks Synthesizer Schematic & Service Manual*, Ural production association "Formanta", USSR.
  * Marc Bareille (Papareil Synth Labs, 2003), *Polivoks VCF Modular Adaptation*.
  * Dave Brown / ModularSynthesis, *Polivoks VCF Analysis & Substitutions*.
* **Circuit Topology & Architectural Idiosyncrasy:**
  * The Polivoks VCF is a 12 dB/octave state-variable filter designed without external integration capacitors in the core filter blocks.
  * Instead, it utilizes two Soviet K140UD12 (К140УД12 / µA776 clone) programmable operational amplifiers where the master cutoff control voltage drives a programming current ($I_{set}$) via an NPN transistor ($KT315\Gamma$ / 2N3904).
  * Sweeping $I_{set}$ modulates the op-amp's internal slew rate and transconductance, dynamically shifting the active integration time constants.
  * **Supported Modes:** Exactly matches the original hardware front-panel SPDT switch:
    * **Low-Pass (LP, mode = 0):** Tapped from the output of the second integrator stage (12 dB/octave roll-off, 2 poles, no transmission zeros).
    * **Band-Pass (BP, mode = 1):** Tapped from the output of the first integrator stage (symmetric 6 dB/octave roll-off skirts with center resonance peak at $f_c$).
    * High-Pass mode is intentionally omitted as it is not present in the historical hardware design.
* **Stage P1: Linearized Two-Stage Discretization:**
  * Bilinear prewarped cutoff coefficient:
    $$g = \tan\left(\frac{\pi f_c}{f_s}\right)$$
  * Analytical damping factor $r$ mapping from resonance parameter $\text{res} \in [0, 1]$:
    $$r = 2.0 \cdot (1.0 - 0.99 \cdot \text{res})$$
    Varying smoothly from $r = 2.0$ (critically damped, $Q = 0.5$) to $r = 0.02$ (high resonance, $Q = 50.0$).
  * Summing junction and integrator equations (TPT / Trapezoidal):
    $$v_{sum} = \frac{v_{in} \cdot \text{drive} - (r + g) s_1 - s_2}{1 + r g + g^2}$$
    $$v_{BP} = g v_{sum} + s_1$$
    $$v_{LP} = g v_{BP} + s_2$$
  * State update equations:
    $$s_1[n+1] = 2 v_{BP} - s_1[n]$$
    $$s_2[n+1] = 2 v_{LP} - s_2[n]$$
  * Unconditional linear stability: because $r > 0$ strictly for all $\text{res} \in [0, 1]$, the denominator $D = 1 + r g + g^2 > 1$ is strictly positive and bounded away from zero, and filter poles lie strictly within the open unit disk $|z| < 1$.
* **Stage P2: Physically Motivated Op-Amp Transconductance Saturation & Rail Clamping:**
  * Slew-rate limiting inside the K140UD12 emerges from differential input pair current saturation charging the compensation capacitor:
    $$\dot{v} = \omega_c \cdot f_{sat}(\Delta V_{in})$$
    where $f_{sat}(x) = \frac{\tanh(\alpha x)}{\alpha}$ with $\alpha = \text{drive}$.
  * Implicit Zero-Delay Feedback Equation:
    $$F(x) = x + r g f_{sat}(x) + g f_{sat}(g f_{sat}(x) + s_1) + r s_1 + s_2 - v_{in} \cdot \text{drive} = 0$$
    with derivative:
    $$F'(x) = 1 + g f'_{sat}(x) [r + g f'_{sat}(u)] \ge 1.0 > 0$$
    guaranteeing a strictly monotonic function, unique real root, and quadratic Newton-Raphson convergence in $\le 3$ iterations.
  * Op-Amp Output Rail Saturation:
    $$v_{out} = \text{soft\_rail}(v) = 1.5 \cdot \tanh(v / 1.5)$$
    prevents integrator state runaway at $r \le 0$ ($res \ge 1.0$) and stabilizes autonomous, non-exploding sinusoidal limit cycles (measured peak $\approx 0.167$, RMS $\approx 0.118$).
  * Small-signal convergence: verified to converge to the linear Stage P1 model to within $< 3 \times 10^{-7}$ for quiet signals.


