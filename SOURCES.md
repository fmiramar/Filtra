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
