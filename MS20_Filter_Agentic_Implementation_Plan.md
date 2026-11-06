# MS-20 Filter Family for SuperCollider — Focused Agentic Implementation Plan

**Target coding agent:** Gemini Flash High  
**Purpose:** Implement a small, scientifically defensible family of real-time SuperCollider UGens for the early Korg-35/MS-20 filter, plus a genuinely useful digital Sallen–Key reference.  
**Design priority:** Correct topology and working sound > breadth of features > circuit-level completeness.  
**Status:** implementation instructions, not a claim that code has already been built or tested.

---

## 0. Read this first: contract for the coding agent

You are working on a **filter implementation task, not an audio framework**.

1. **Inspect the existing repository first.** Reuse its CMake, SC plugin conventions, naming style, existing test scripts, and helpfile layout. Do not restructure it. Do not generate another project if one exists.
2. **Implement only the next authorized milestone.** Finish it, compile, run the smallest meaningful audio tests, then report and stop. Do not automatically implement later milestones.
3. **Do not create** GUI, metering suites, LUFS calculations, plugin host, standalone synthesizer, wave visualization framework, preset browser, benchmark infrastructure, CI overhaul, dependency manager, or multi-agent machinery.
4. **No new external dependencies** unless an absolutely unavoidable library is already installed. Use simple C++ and the SuperCollider plugin API. A small offline Python/Numpy script is optional only if essential to verify the transfer function.
5. Avoid speculative optimization. No SIMD, AVX, template-heavy generic framework, runtime polymorphism, or generalized circuit solver in the first three milestones.
6. Keep models **separate and independently auditionable**. No 20-position algorithm switch, and no user-facing controls that have no demonstrable acoustic purpose.
7. **Do not silently replace the historical MS-20 HPF with a conventional second-order HPF.** The relevant Korg-35 MS-20 HPF is resonant but has a *6 dB/octave asymptotic low-frequency attenuation*, not 12 dB/octave.
8. **Do not claim** circuit-level fidelity when the implementation uses an approximate transfer function or a generic soft clipper. Label models accurately.
9. Never create a unit-delay feedback loop where the reference model calls for zero-delay/implicit feedback without documenting the audible and stability consequences.
10. Never paste third-party DSP source without checking the specific code's license and compatibility with the intended repository license. Equations, topology descriptions and independent derivations are the preferred starting point.
11. **No lengthy literature-review deliverable.** Read only the relevant sections of the linked references; maintain a compact `SOURCES.md` or equivalent section with URLs, license findings and specific implementation decisions.
12. Before every significant code change, state: **which UGen, which equation/topology, what test will show it works**. If a source is ambiguous, surface the uncertainty rather than inventing a circuit fact.

**First stop condition:** Deliver the linear Sallen–Key reference, its LP and authentic MS-20-style HP modes, a compiling plugin, a runnable `.scd` demo, and brief numerical/sound sanity checks. STOP and ask for the next milestone only after these exist.

---

## 1. Essential electrical facts

- The **early Korg-35/MS-20** employs a Sallen–Key-type circuit with two voltage-controlled resistive elements based on transistors operating in reverse saturation, capacitors, amplifier gain and resonance feedback. The two RC sections **load one another**. The diode gain limiting is in the **forward amplifier's local feedback**, yielding a nonlinear forward gain function.
- The **later MS-20 OTA revision (KLM-307 / LM13600)** uses two buffered first-order stages with a different resonance network. It is **not the same Sallen–Key structure**. Its limiting diodes appear in the **resonance-feedback amplifier**, rather than the same forward-path location as the original.
- The **MS-20 HPF is not a trivial `input - LPF` output and not the normal RC/CR dual of a two-pole Sallen–Key low-pass**. Korg moved the input to the formerly grounded end of a capacitor and grounded the LP input. It retains a resonant second-order denominator but has a first-order low-frequency asymptote.
- The **complete MS-20 filter signal path** is **HPF -> LPF**, each with its *own* cutoff and resonance. Compose this using two UGen instances in SuperCollider; a monolithic dual-filter UGen is not required.
- The same named `res` or `peak` knob is **not automatically equal to mathematical Q**. Do not infer 0–1 knob range = 0–1 Q. A useful normalized performance control needs its own documented mapping to the actual feedback parameter.
- Pure linear filters at the marginal stability/self-oscillation boundary cannot safely maintain bounded oscillation on their own. The nonlinear limiter should bound resonance in the nonlinear model; do not conceal instability behind arbitrary continuous hard clipping.

**Primary circuit reference:** T. E. Stinchcombe, *A Study of the Korg MS10 & MS20 Filters* (2006, minor corrections 2009), especially §§2, 4, 5 and 7.  
https://www.timstinchcombe.co.uk/synth/MS20_study.pdf

## 2. Exact minimal deliverables and model names

The API below is a proposed convention; if the existing repo has a consistent naming convention, adopt it **without** changing algorithm identities.

| Model | Required now? | Suggested UGen | What it actually represents |
|---|---|---|---|
| **A. Direct digital Sallen–Key** | **Milestone 1** | `MS20SK` | **Linear, component-topology-informed** early MS-20 Korg-35 LP and special HP. Bilinear transform of independently derived analog transfer functions, retaining the loading term. No saturation. Serves as reference; not marketed as a complete hardware emulation. |
| **B. TPT / zero-delay Korg-35** | **Milestone 2** | `MS20TPT` | Independently formulated topology-preserving (ZDF) Korg-35 LP and HP, including explicit stable treatment of the resonance loop. Linear first, nonlinear **off**. |
| **C. Nonlinear Korg-35** | **Milestone 3** | `MS20Diode` | Model B's electrical filtering plus a physically motivated diode-limited amplifier transfer function inserted at the **correct circuit location**. With `drive` and resonance. |
| **D. Later OTA MS-20** | **Optional, separate approval** | `MS20OTA` | Two buffered first-order OTA-style stages, independent correct HP structure, resonance limiter in the **feedback path**; not just a renamed Korg-35 implementation. |
| **E. WDF/MNA circuit research model** | **Research backlog only** | `MS20Circuit` (provisional) | A genuinely distinct component-level nonlinear model, **only** if A–D sound/analysis or hardware comparisons warrant the extra CPU and development. |

**Do not implement all five by default.** Start with A. The first meaningful musical comparison is A vs B vs C; D only after those work. E is explicitly not in the initial scope.

### Proposed minimal SC-facing signature

```supercollider
// Parameters and names may be adapted to existing repository conventions.
MS20SK.ar(in, freq = 1000, res = 0.25, mode = 0);
MS20TPT.ar(in, freq = 1000, res = 0.25, mode = 0);
MS20Diode.ar(in, freq = 1000, res = 0.25, drive = 1.0, mode = 0);
// mode: 0 = LP, 1 = historically appropriate MS-20 HP; i-rate only.
// in: audio-rate; freq and res: initially i/k-rate controls.
// Add sample-accurate frequency modulation only after ordinary operation is correct.
```

Expose **no** wet/dry, global loudness trim, noise generator, arbitrary filter slope, filter morphing, stereo spread, auto-gain, oversampling choice, filterbank, or built-in modulation oscillator. These are outside scope. In SC, multichannel expansion and serial HP->LP processing already work naturally.

The `res` normalized range must be defined mathematically in the docs. Avoid an API in which `res = 1` secretly means a hard-coded singularity that becomes unbounded in Model A. The normalized mapping and safe endpoint can differ by model if **clearly documented**; when comparing models, additionally allow comparison at matched resonant peak gain / matched pole damping.

---

## 3. Milestone 1 — direct digital Sallen–Key model (the important baseline)

**Goal:** minimal digital implementation of the actual *linearized* Korg-35 Sallen–Key topology and its nonstandard HP input wiring.

### A1. Derive the continuous-time reference, do not start from generic cookbook biquads

1. Open Stinchcombe §§2.2 and 7. Draw the LP and HP circuits with labelled input, both RC nodes, amplifier gain `k1`, resonance-feedback attenuation `k2`, resistances and capacitors.
2. Write Kirchhoff nodal equations, including **loading of R2/C2 upon the first stage**. Start with the general component form rather than immediately assuming all components are equal.
3. Verify the equal-component **linear LP** transfer function using `u = s/ω0`, `ω0 = 1/(RC)`, and `K = k1*k2`:

   `H_LP(s) = k1 / [u² + (3 - K)u + 1]`.

4. Verify the associated **MS-20-style HP** from the *correct rewired input*, under the same equal-component simplification:

   `H_HP(s) = k1 * (u² + 2u) / [u² + (3 - K)u + 1]`.

5. Check LP: DC passband, 12 dB/oct high-frequency asymptote. Check HP: zero DC gain and ~6 dB/oct low-frequency asymptote despite a quadratic denominator. The exact high-frequency gain depends on amplifier/normalization assumptions.
6. **Important:** the equal-R, equal-C normalization is a useful verification case, **not** a claim that the physical Korg-35 board uses identical component values. The paper discusses unequal capacitor/resistor relationships (notably C1/C2 and effective transistor resistance). Preserve the *general* component model if it can be implemented with essentially the same complexity; otherwise document the equal-component approximation.

### A2. Discretization

1. Construct the continuous linear transfer function from the derived circuit parameters.
2. Convert it to digital form by a **bilinear transform (Tustin)**, ideally prewarping the specified analog reference frequency: `ωa = 2*fs*tan(π*fc/fs)`.
3. Evaluate the resulting real second-order difference equation with two state samples (e.g., transposed direct form II), **not** a recursive high-order framework.
4. Do not apply a separate cutoff correction formula copied from a generic biquad: the chosen prewarp establishes the reference frequency correspondence. Be explicit whether the `freq` value means natural frequency `ω0/(2π)`, -3 dB cutoff, or another calibrated knob convention. They diverge at high resonance.
5. Pole placement: clamp to a **documented stable linear range**. As the linear resonance approaches infinite-Q, warn in the helpfile that Model A cannot yield safely bounded free oscillation. Permit enough range to demonstrate high resonance without uncontrolled output.
6. Check float coefficient calculation, valid low/high cutoff, subnormal handling and state reset. Do not insert a generic `tanh` or limiter in Model A.
7. If control values change, update coefficients at **control/block boundaries** initially, using simple smoothing only if audible stepping requires it. Avoid forcing all coefficient work to the sample loop for a k-rate signal. Document that time-varying parameters mean the resulting system is not equivalent to one fixed bilinear transfer function.

### A3. What to deliver

- One functioning `MS20SK` UGen (`.ar` only is fine), LP/HP selector at construction time.
- One helpfile with short explanation and exactly three practical examples: noise LP sweep, noise HP sweep, audible resonance sweep.
- One `.scd` comparison demonstrating `HP -> LP` as two instances.
- One compact set of numerical checks for LP DC/roll-off; HP DC/6 dB/oct; sample-rate consistency; stable outputs.

**Stop here.** Do not begin nonlinear or OTA variants automatically.

---

## 4. Milestone 2 — topology-preserving / zero-delay model

**Goal:** implement a structurally different model that follows the Korg-35 feedback graph in discrete time, with no invented unit delay in the resonant loop.

### B1. Read before coding

- Will Pirkle, *Virtual Analog Korg35 Lowpass Filter*, App Note 5, version 3.5 (2013). Obtain the official original if accessible; cross-check against the Csound implementation and published documentation. Pay special attention to **loaded vs buffered** assumptions and the differing critical gains often described as `K = 3` vs `K = 2` under simplified equal-R/C assumptions.
- Will Pirkle, *Virtual Analog Korg35 Highpass Filter Simplified*, App Note 7A, v2.0 (2013): https://www.willpirkle.com/Downloads/Korg35HPFAppNote_V2.pdf
- Vadim Zavalishin, *The Art of VA Filter Design* (2012), for trapezoidal integrators, TPT and zero-delay algebraic feedback.
- Csound's independently testable implementations and user documentation: https://csound.com/docs/manual/k35_lpf.html and https://csound.com/docs/manual/k35_hpf.html

### B2. Implementation steps

1. Identify TPT integrator states and local feedforward/feedback equations for the exact early LP and HP topologies. **Do not share a single LP/HP structure merely by taking output complements.**
2. Use trapezoidal integrator building blocks, generally `g = tan(π*fc/fs)` and `G = g/(1+g)` for a one-pole stage, subject to the actual topology and correct stability/range treatment.
3. Explicitly solve the **linear algebraic feedback** for the current sample. The zero-delay calculation must be algebraic, not an iterative search when the loop is linear.
4. Differentiate the **loaded Sallen–Key** expression from a buffered approximation. If following Pirkle's buffered algebra for performance, label that as an approximation, retain an A/B reference to the loaded Model A, and describe the different nominal self-oscillation condition.
5. Verify the **frequency-response agreement** between A and B when both represent the *same* linear circuit, coefficient parameters, gains, and sample rate. They should agree to reasonable numerical tolerance at static settings. If not, resolve topology/normalization before exploring nonlinearities.
6. Initially use the same `in`, `freq`, `res`, `mode` API, making it possible to audition with identical SC source signals.

### B3. Completion gate

- Builds and runs without NaNs/Inf or signal explosion for all documented stable settings.
- LP/HP slopes match expected asymptotes.
- Measured resonant frequency and gain are compared against Model A at 44.1, 48, and 96 kHz (only a few cases needed).
- Cutoff sweeps with nonzero resonance do not show obvious discontinuities or sample-rate dependent feedback delay errors.
- Explain **why B exists if A sounds similar**: topology-preserving feedback is a better foundation for *later* nonlinear components and parameter modulation. Similarity in the linear time-invariant case is expected, not failure.

**Stop here unless Milestone 3 is explicitly authorized.**

---

## 5. Milestone 3 — nonlinear early Korg-35 model

**Goal:** capture the strongest audible character of the original filter without turning the work into a complete SPICE engine.

### C1. Nonlinear transfer functions: shortlist to audition

Implement the following **one at a time inside the same topology**, not as unrelated effects:

1. **Piecewise or smoothly limited amplifier gain motivated by back-to-back diodes** (first choice): lower gain once diode conduction becomes significant; derive its qualitative shape from Stinchcombe §5. Record where it sits in the feedback structure of the *forward amplifier*.
2. **Diode-equation-like implicit gain** (higher physical plausibility): use an anti-parallel diode current or differentiable static equivalent with voltage scaling. If implicit, use a compact bounded Newton method / precomputed 1-D inverse curve, with explicit fallback if convergence fails. Do **not** start with a general SPICE solver.
3. **`tanh` as a controlled approximation** (A/B diagnostic, not historically exact): a normalized, continuously differentiable soft limit applied at that same physically motivated location. Compare timbre and stability; document what the shortcut omits.

Do not indiscriminately put a clipper at the final UGen output and call that analog modeling. Do not move the saturation to the OTA feedback location: that belongs to Model D.

### C2. Calibration and numerical details

1. Define `drive` as a dimensionless control affecting the amplifier's nonlinear *input scale*. `drive = 1` is nominal, not an assertion about actual physical volts at the jack.
2. Use a predictable output gain convention and document it. Do **not** normalize each sample or constantly auto-adjust loudness; that destroys real drive/resonance interaction.
3. At minimum compare **three input levels** (quiet/nominal/hot), **three resonance settings** (low/mid/high) and **three frequencies** (below/near/above `fc`). Retain results in a terse text table or example script, not an elaborate analysis system.
4. At high resonance, verify whether oscillation starts, persists and is bounded. Do not infer correct oscillation merely because a square wave is being produced by clipping.
5. Start at 1x processing. Test a hard-driven high-frequency sine/saw for **aliasing**. Add a limited **2x oversampling internal mode** only when audible/visible aliasing justifies its cost. 4x can remain a research note. Do not introduce a general resampler framework.
6. If numerical stability at extreme settings requires clipping an internal variable, justify that clipping as an approximation and ensure it does not mask faulty filter coefficients.

### C3. Success condition

The result must differ *meaningfully* from the linear model at high input level/resonance, remain similar near small signal levels, exhibit stable bounded behavior, and make clear which specific electrical mechanism causes the difference.

---

## 6. Later candidates — catalog of analog/digital models (not initial work)

The following are distinct modeling strategies, **not** permission to implement them all.

| Approach | Historical/physical interpretation | Cost and value | Action |
|---|---|---|---|
| **Analog transfer-function -> bilinear biquad** | Exact **linearized** LP/HP transfer functions including loading, and an analytically simplified equal-RC case | Very low CPU; essential clean reference | **Implement A** |
| **TPT/ZDF circuit graph** | Preserves current-sample resonance feedback, analytically solves algebraic loops | Low CPU; strong base for nonlinearity and modulation | **Implement B** |
| **Nonlinear forward amplifier (diode clipping)** | Early Korg-35 back-to-back diode gain stage | Moderate CPU, high audible relevance | **Implement C** |
| **Simplified tanh/soft-clip approximation** | Cheap surrogate for diode limiting | Low CPU; useful control comparison, not separate product by default | **Test inside C** |
| **Antiparallel Shockley diode / nonlinear op-amp relation** | More faithful diode dynamic and signal-level-dependent gain | Moderate/higher CPU; solve nonlinear loop carefully | **Optional refinement of C** |
| **Nonlinear transistor-variable-resistance model** | Reverse-saturated Korg35 BJT pair, current-to-cutoff and signal-dependent resistance | High complexity; may add accuracy under extreme drive | **Research later** |
| **OTA/LM13600 later filter** | Two buffered OTA RC-equivalents; diodes in feedback amplifier; perhaps OTA input-pair nonlinearities | Different sonic family; not the Korg-35 topology | **Optional D** |
| **Wave Digital Filters (WDF)** | Circuit-oriented wave scattering with capacitors, resistors, nonlinear active portions | Higher engineering cost; potentially faithful and stable | **Optional E if justified** |
| **Modified nodal analysis + trapezoidal implicit integration** | Component-level discretized KCL/KVL with a small nonlinear solver | High CPU; compare against SPICE, not a first implementation | **Optional E only** |
| **Continuous-time state equations integrated via RK2/RK4** | Direct ODE simulation of a simplified nonlinear circuit | Potential CPU/aliasing/stability costs; no clear advantage by itself | **Experiment only if motivated** |
| **SPICE / ngspice offline circuit simulation** | Electrical reference using documented component values | Offline, not a real-time UGen | **Use later for validation, if needed** |
| **Hardware-measured parameter fitting** | Fit peak position, resonance curve, harmonic amplitudes and drive response to an actual unit | Only meaningful with labeled Korg-35 vs OTA recordings and level calibration | **Not possible to claim fidelity without data** |
| **Control-law component mismatch / CV feedthrough** | Imperfect vintage resistor tracking, tolerance, DC offsets, thermal drift | Secondary effect; easy to overdo | **Defer** |

**Related but not the same circuit:** Rest, Parker & Werner's *WDF Modeling of a Korg MS-50 Based Non-linear Diode Bridge VCF* (DAFx 2017) is useful as a **methodological** example, NOT a direct MS-20/Korg-35 implementation. It concerns a distinct MS-50 diode-bridge filter: https://www.dafx.de/paper-archive/details/hiqpX15QjOgjE5JKCYW44g

---

## 7. Minimal SuperCollider engineering requirements

### DSP and graph behavior

- Use the repository's normal `scsynth` UGen plugin interface. Mono unit implementation is sufficient; SuperCollider already supplies multichannel expansion.
- Audio input is `.ar`; initially support `freq` and `res` as scalar or control-rate inputs. Do not promise audio-rate cutoff modulation until actually implemented and tested.
- `mode` is an **i-rate** construction selector, not something to change mid-buffer. It must select genuinely different LP/HP numerator/wiring behavior.
- Clamp `freq` to a documented **safe internal range** relative to the current sample rate (avoid `tan(π/2)` / Nyquist singularity) and make `freq <= 0` handling deterministic. Clamp `res` to the model's safe valid range.
- Initialize all states at UGen construction; define behavior on note retrigger/new Synth; do not share state between instances.
- Never allocate memory, perform file I/O, throw exceptions, make logs, or lock a mutex in the audio `next` function.
- Calculate coefficient changes efficiently (at k rate for k-rate controls). Use double arithmetic internally only where needed for stable coefficients/feedback; assess audio output against `float` SuperCollider buffers.
- Ensure no denormals, NaNs, unbounded DC drift or startup impulses. Avoid overly aggressive hidden output limiting.
- Demonstrate `HP -> LP` in the SC example; it should not require a new UGen.

### Small, sufficient test matrix

| Test | Input and settings | Expected outcome |
|---|---|---|
| Build/load | Installed SC, load each class | No missing UGen, crash, invalid constructor |
| LP low resonance | Impulse/noise, several cutoffs | Approximately 12 dB/oct stopband above cutoff; correct low-frequency passband |
| MS-20 HP low resonance | Impulse/noise, several cutoffs | Zero DC transfer and approximately 6 dB/oct attenuation well below cutoff |
| Frequency mapping | 100, 1000, 5000 Hz at 44.1/48/96 kHz | Similar analog-target response after prewarp, no gross sample-rate drift |
| Resonance | Three safe values and a cutoff sweep | Peak grows/changes as expected; no unstable startup in documented range |
| Drive (C only) | Sine and saw; 3 drive levels | Low-level near linear; high-level adds bounded harmonics |
| Silence / DC | Silence, tiny DC, then audio | No NaNs, denormals, spontaneous nonphysical blow-up |
| Automation | One slowly varying cutoff and one quick jump | No crashes; clicks addressed only if actually problematic |
| 2 instances in series | `HP -> LP` | Plausible resonant band-pass-like effect; separate parameters independent |

**Do not create dozens of golden WAV snapshots, spectral dashboards or a large test harness.** Use one compact `.scd` smoke test plus a few numerical asserts where straightforward.

### Minimal audition patch (adapt class names as needed)

```supercollider
(
// Requires that the UGen classes have been compiled and installed.
// Start quietly: high resonance can be loud.
{
    var src = (Saw.ar(110) * 0.07) + (PinkNoise.ar(0.015));
    var hp = MS20SK.ar(src, 160, 0.25, 1);
    var lp = MS20SK.ar(hp, XLine.kr(7000, 180, 12), 0.35, 0);
    (lp * 0.15) ! 2
}.play;
)
```

---

## 8. Model-to-model evaluation: what actually matters

Compare **small signal vs large signal**, not just which implementation has the strongest output:

- **Linear response:** 12 dB/oct LP and 6 dB/oct HP; cutoff mapping; resonant peak location and width; passband gain.
- **Nonlinear response:** hard/soft onset of diode limiting, input level dependency, harmonic pattern, variation of resonance as drive rises, self-oscillation/limit-cycle character, DC offset and aliasing.
- **Numerical response:** block-size independence when static, stability during cutoff modulation, Nyquist behavior, bounded states.
- **Performance:** compare CPU of A/B/C in the **same** number of active Synth nodes and identical settings; report relative differences, without building a separate benchmarking product.

An algorithm that merely has more harmonics is not necessarily more historically accurate. Actual hardware comparison requires documentation of the **specific MS-20 filter revision**, input/output calibration and appropriate recordings or component reference simulation.

---

## 9. Short workflow for Gemini Flash High

**Execute one milestone per prompt/context.** Recommended order:

**Prompt A — FIRST:**
> Inspect this repo and implement only Milestone 1 of `MS20_Filter_Agentic_Implementation_Plan.md`. First summarize the two analog transfer functions and the HP 6 dB/oct reason. Then make the smallest compiling `MS20SK` UGen (LP+HP i-rate mode), one small helpfile/demo, and minimal verification. Do not start other models or add any infrastructure. Report the files changed, the exact build/test commands and unresolved assumptions. Stop.

**Prompt B — AFTER A is accepted:**
> Implement only Milestone 2 (`MS20TPT`), independently of `MS20SK`; use a zero-delay topology-preserving formulation of the early Korg-35 LP and HP. Demonstrate static agreement with the same linear analog target, and document any loaded-vs-buffered approximation. Do not add saturation or OTA models. Stop after compilation and a short A/B test.

**Prompt C — AFTER B is accepted:**
> Implement only Milestone 3 (`MS20Diode`) by adding the early Korg-35 forward amplifier nonlinearity in the correct place. Compare an electrically motivated limiter against a tanh approximation using three input levels and three resonance settings. Keep the cheapest stable approach unless meaningful benefits justify the more expensive one. Do not add unrelated features. Stop.

**Prompt D — optional, after listening:**
> Implement the later OTA revision as a separate model only. Derive its own buffered stages and feedback limiter from the KLM-307 reference. Do not reuse the Korg-35 equations simply by swapping the clipping function.

**Failure policy:** If compilation or audio execution is unavailable, produce the smallest compile-ready patch and exact verification commands, label checks as **not run**, and stop. Never claim a feature or benchmark was tested when it was not.

**Agent context budget:** Do not read all unrelated files or rewrite unrelated UGens. If a derivation occupies an excessive number of turns, use Stinchcombe's documented transfer function and document it; prioritize getting the working Model A. When uncertain, one short note and one chosen implementation beats a multi-page speculative analysis.

---

## 10. Sources, existing implementations and provenance

### Indispensable circuit and algorithm sources

1. **Timothy E. Stinchcombe (2006/2009), _A Study of the Korg MS10 & MS20 Filters_.** Early Korg-35 vs late OTA topology; linear transfer functions; reversed transistor behavior; diode limiting and the 6 dB/oct HPF. https://www.timstinchcombe.co.uk/synth/MS20_study.pdf
2. **Stinchcombe's source/schematic catalog.** Access point for vintage Korg35 and KLM-307, clones, comparisons. https://timstinchcombe.co.uk/index.php?pge=korg
3. **Will Pirkle (2013), _Virtual Analog Korg35 Lowpass Filter_, AN-5 v3.5.** Topology-preserving LP implementation, loaded/unloaded caveat. The source is cited from Csound and Soundpipe documentation; official historical URL `https://www.willpirkle.com/Downloads/AN-5Korg35_V3.pdf` may have moved. **Do not assume availability.**
4. **Will Pirkle (2013), _Virtual Analog Korg35 Highpass Filter Simplified_, AN-7A v2.0.** https://www.willpirkle.com/Downloads/Korg35HPFAppNote_V2.pdf
5. **Vadim Zavalishin (2012), _The Art of VA Filter Design_.** Topology-preserving transform, one-pole TPT, ZDF. Consult the author's distributed original or reliable hosting; verify access before quoting.
6. **James J. Clark (2005), _The Design of a Reaktor Core Model of the Korg MS-20 VCF_.** Alternative numerical integrations and their caveats. Based on a Doepfer-style inspired circuit rather than guaranteed component-level Korg35 reproduction. https://www.cim.mcgill.ca/~clark/patches/mx20_design.pdf

### Code and comparisons (licenses must be checked)

7. **Csound K35 LPF/HPF**, by Steven Yi (2017): documentation and runnable external reference. https://csound.com/docs/manual/k35_lpf.html , https://csound.com/docs/manual/k35_hpf.html
8. **FAUST `vaeffects.lib`, `korg35LPF` and `korg35HPF`**, by Eric Tarr (2019). Useful to inspect *different* LP/HP graphs; **license notice is `LicenseRef-STK-4.3` for the implementation** — verify how it applies and do not automatically copy into a GPL/LGPL/other repo. https://github.com/grame-cncm/faustlibraries/blob/master/vaeffects.lib
9. **Soundpipe `wpkorg35`** (Pirkle-derived LP model) and **ChucK `WPKorg35`** as independent auditory/behavioral references, subject to their licensing. https://paulbatchelor.github.io/res/soundpipe/docs/wpkorg35.html , https://chuck.stanford.edu/doc/reference/chugins.html
10. **Surge XT K35 filter** (inspired by Odin 2 implementation), useful as an open-source musical comparison, not necessarily a component-accurate historical reference. https://surge-synthesizer.github.io/manual-xt/index.html

### Advanced research, not initial implementation tasks

11. **M. Verasani, A. Bernardini, A. Sarti (2017), _Modeling Sallen-Key Audio Filters in the Wave Digital Domain_**, ICASSP 2017. WDF treatment of general Sallen–Key classes; a methodology rather than a ready-made full MS-20 emulation. https://re.public.polimi.it/handle/11311/1061665
12. **K. J. Werner et al. (2018), _Modeling Circuits With Arbitrary Topologies and Active Linear Multiports Using Wave Digital Filters_.** For more intricate active WDF circuits. https://re.public.polimi.it/handle/11311/1061638
13. **Stefano D'Angelo (2014), _Virtual Analog Modeling of Nonlinear Musical Circuits_.** Background for nonlinear MNA/WDF/implicit discretization. https://dangelo.audio/va-modeling
14. **M. Rest, J. D. Parker, K. J. Werner (2017), _WDF Modeling of a Korg MS-50 Based Non-linear Diode Bridge VCF_.** Methodological analogue only, different Korg circuit. https://www.dafx.de/paper-archive/details/hiqpX15QjOgjE5JKCYW44g
15. **D. Albertini, A. Bernardini, A. Sarti (2020), _Antiderivative Antialiasing in Nonlinear Wave Digital Filters_.** Optional advanced anti-aliasing research if future WDF model warrants it. https://www.dafx.de/paper-archive/details/1VN4BTM85kVIGKymyKzBXg

---

## 11. Definition of done for the first release

A first **useful** release does not need a general filter framework. It needs:

- [ ] `MS20SK` valid and stable LP + authentic 6 dB/oct MS-20-style HP behavior.
- [ ] `MS20TPT` zero-delay-feedback LP + HP with documented model assumptions.
- [ ] `MS20Diode` musically meaningful nonlinear behavior at the correct early Korg-35 stage.
- [ ] Three minimal `.schelp`/help examples and one small `.scd` side-by-side comparison (can be a single shared example if it demonstrates all three clearly).
- [ ] Correct CMake/build integration and no extra dependencies.
- [ ] One brief README explaining **what each model is / is not**.
- [ ] Concise build/run report with actual tests and untested limitations.

**Not needed for the first release:** OTA model, true transistor-level model, WDF model, GUI, oversampling UI, stereo UGen, presets, detailed loudness metering, profiling suite, exhaustive tests, continuous integration redesign, or audio-rate modulation unless already straightforward in the architecture.

**Final instruction to the agent:** The immediate next action is **Milestone 1 only**. Build the smallest working `MS20SK`, verify LP/HP asymptotes and sample-rate consistency, document what you actually did, and stop.
