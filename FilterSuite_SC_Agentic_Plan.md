# FilterSuite — focused agentic plan for compiled SuperCollider UGens

**Target coding agent:** Gemini Flash High  
**Project:** a GitHub repository containing native, compiled SuperCollider server plug-ins, plus their minimal `.sc` class wrappers and examples  
**Date:** 2026-11-06  
**Starting state:** the Korg MS-20 filter implementations are **already complete**. They are **not** part of this implementation plan.

> **Prime directive:** Implement **one bounded, testable filter at a time**. An excellent working filter is worth more than a large unfinished DSP framework. Do not interpret this plan as permission to implement every filter in one run.

## 0. Read these instructions before touching the repository

1. **Inspect the actual repository first.** Read its README, existing `.cpp`, `.h`, `.sc`, CMake and build scripts, license, examples, and existing compiled targets. Do not assume it follows any layout illustrated here. Confirm whether the completed MS-20 filters are in the same repository. Preserve them and their public APIs.
2. **Native extensions, not a Quark:** implement SuperCollider **server-side C++ UGens** that load in `scsynth`. Supply lightweight `.sc` UGen classes and, where appropriate, `.schelp` class help; distribute compiled plug-in binaries through **GitHub Releases**. Do not add `.quark`, Quarks installation, GUI, SynthDef library, or sclang-only emulations as shipping substitutes.
3. **Do not duplicate existing UGens:** compare against the present repository, `chowdsp-sc-ports` (`SallenKeyCh`, `WernerCh`, `WarpCh`, `VogueLadderCh`, `ARPFilterCh`, etc.), SuperCollider built-ins, sc3-plugins and PortedPlugins (particularly `VASEM12`, `VADiodeFilter`, `VAKorg35`, `VadimFilter`). Existing MS-20: **completed; never reimplement.**
4. **Implement only the milestone explicitly requested by the human.** If instructed to implement Wasp stage 1, do not silently also implement Polivoks, custom oversamplers, release workflows or new generic libraries. Stop after compiling, testing, and reporting that milestone.
5. **Work from equations, not guesswork.** For analog models, locate a definite circuit version, schematic, paper or datasheet; identify which physical properties are modeled. Differentiate (a) digital topology-inspired filter, (b) nonlinear circuit-informed approximation, and (c) validated circuit emulation. Do not call (a) or (b) an exact emulation.
6. **No real-time hazards:** no allocations, locks, file I/O, logging, exceptions or table construction in the audio callback. Allocate states at initialization; free at destruction. No buffer overruns, NaNs or infinite values. Handle sample-rate changes and audio/control-rate input expectations correctly.
7. **Avoid false fidelity.** Do not create a `drive` knob that is merely `tanh(output)` and market the result as transistor/OTA/CMOS behavior. The position of nonlinearities within the feedback network matters.
8. **Avoid overengineering.** Do not implement LUFS, spectral analysis frameworks, visual dashboards, GUI panels, plugin hosting (VST/AU/CLAP), elaborate preset systems, ML models, automatic gain control by default, or documentation websites. Do not rewrite the SC build system or unrelated files.
9. **Do not hide uncertainty.** If a component law, schematic revision, coefficient derivation or a license is uncertain, label it and use a documented approximation or defer the filter. Never fabricate equations or claim a test was executed if it was not.
10. **Respect source licenses.** Research papers, reference schematics and permissively licensed code are not equivalent to a blanket license to copy implementation files. Prefer independently derived code. Record sources/attributions; if porting GPL code, explicitly assess compatibility with the repository's license before copying.

### Definition of a complete milestone

A filter milestone is complete when it **builds**, loads in `scsynth`, produces sensible audio, passes its specific small tests, has a minimal runnable SC example, and lists its limitations. No extra polish is required.

Every coding-agent reply must end with this short report:

```
MILESTONE: [filter / stage]
FILES CHANGED: [paths]
MODEL: [topology; analog revision/source if relevant]
TESTED: [build command, SC boot, test stimuli, results actually observed]
NOT TESTED: [clearly listed]
LIMITATIONS: [known mismatches / artifacts / uncertainty]
NEXT SUGGESTED ACTION: [one sentence]
STOPPED: yes
```

---

## 1. Scope and recommended build order

**All 12 candidates from the shortlist are captured below**, but **only the first five are prioritized**. The rest are individually authorized *only when explicitly selected*, not required for an initial release.

| Order | Proposed class | Model / approach | Status | Expected effort | Reason to implement |
|---|---|---|---|---|---|
| — | Existing MS-20 classes | Korg-35 and/or OTA implementations already made | **DONE — DO NOT TOUCH** | — | Preserve prior work |
| 1 | `FSWasp` | EDP Wasp OTA + CMOS-inverter SVF | Core | High, split into two stages | Truly distinctive nonlinear architecture; 2022 DAFx model |
| 2 | `FSSteiner` | Steiner–Parker diode multimode VCF | Core | Medium | Unusual diode-controlled multimode response |
| 3 | `FSPolivoks` | Programmable-op-amp slew-limited VCF | Core | Medium–high | Distinct integrator nonlinearity |
| 4 | `FSZMorph` | Original multiresonant digital filter morph | Core | Medium | New compositional control space |
| 5 | `FSDispersion` | Stable cascaded dispersive all-pass | Core | Low–medium | New phase/group-delay processing |
| 6 | `FSRolandOTA` | IR3109-style OTA cascade | Later | Medium | Specific Roland topology and feedback |
| 7 | `FSCS80` | Independently resonant HP → LP pair | Later | Low–medium | Strong functionality at low cost |
| 8 | `FSChipVCF` | **One** selected SSM2044 **or** CEM3320 circuit | Conditional | Medium–high | Only if circuit-specific differences justified |
| 9 | `FSNLMS` | Adaptive normalized LMS FIR | Later | Medium | Useful algorithmic processing beyond classic VCFs |
| 10 | `FSFormantMorph` | Stable morphing formant filterbank | Later | Low–medium | Coordinated spectral envelope motion |
| 11 | `FSVCFQ` | Serge variable-Q/ping behavior | Conditional | Medium | Only if demonstrably unlike generic SVF |
| 12 | `FSDynamicSOS` | Modulation-safe time-varying IIR sections | Conditional | Medium–high | Only if it outperforms existing facilities |

**Execution rule:** *One row at a time.* For example, do not start row 2 until row 1's selected stage passes its acceptance checks. Rows 8, 11, and 12 need a brief go/no-go investigation before implementation; a justified **SKIP** is a successful outcome.

**Initial release target:** at most `FSWasp`, `FSSteiner`, `FSPolivoks`, `FSZMorph`, and `FSDispersion`, **only after each is independently finished**. The initial release may contain fewer filters; never delay a useful release simply to fill the table.

### Additional ideas — research backlog only (no code authorization)

Buchla 291 resonant band-pass; Buchla 292 low-pass gate (already modeled elsewhere); EMS/VCS3 diode ladder; ARP 1047; wah inductor circuits; passive guitar amp tone stacks; through-zero SVF experiments; nonlinear feedback placements; modulated comb banks; warped-frequency-axis IIR; elliptic filters; linear-phase crossover FIR; time-varying spectral-envelope filter. **No work on these unless explicitly requested.**

---

## 2. One-time repository setup (strictly minimal)

### Stage 0A — short audit (no new code)

- Determine the repository name, directory structure, target SuperCollider version, C++ standard, compiler, and actual build invocation.
- Search current and external installed class names for conflicts with proposed `FS*` names. If a conflict exists, change names consistently **before** shipping.
- Identify existing MS-20 implementations, their names and public API. **Do not modify them** except for a demonstrably necessary build fix explicitly approved by the human.
- Record whether the project already has GitHub Actions, releases, Linux/macOS configurations, and a license.
- Write a *short* `IMPLEMENTATION_STATUS.md` or update an existing status section: filter name, `not started / in progress / passed / blocked / skipped`, one-sentence reason. Avoid a large project-management system.
- Compare external prior art **only for the selected filter**. Do not spend a whole milestone auditing dozens of repositories.

**Stop:** report the exact build command and the next chosen filter. No scaffolding marathon.

### Stage 0B — only if the repository lacks usable plugin infrastructure

Use official SuperCollider compiled-plugin conventions and CMake. Follow the existing project first; otherwise this minimal shape is sufficient:

```
FilterSuite/
  CMakeLists.txt
  README.md
  LICENSE
  src/
    FilterSuite.cpp                # registration / entry points (if existing style supports this)
    Wasp.cpp                       # or a separate source file per UGen
    WaspDSP.h                      # optional, only if useful
  Classes/
    FSWasp.sc
  HelpSource/Classes/
    FSWasp.schelp                  # concise, after UGen works
  examples/
    wasp_basic.scd
  IMPLEMENTATION_STATUS.md
```

Do not force this layout onto an established repository. A single shared compiled plugin containing multiple registered UGen classes is fine, as are multiple compiled libraries if the existing build uses them. Do **not** create a general DSP engine, plugin factory, common modulation framework, or a separate C++ library per circuit.

**Mandatory UGen conventions**

- Audio processing must run in `scsynth`; light `.sc` classes only expose `.ar` and arguments.
- Input signal at audio rate. Control signals may be control-rate unless audio-rate control is explicitly supported and tested; **do not advertise `.ar` modulation that the native code silently samples only once per block**.
- Clarify which parameters are init-only (e.g. mode, preset IDs, fixed stage count) and which may be modulated at k-rate/a-rate. Clamp physically invalid parameters before coefficient calculation.
- Init all filter memories and output buffers. Handle SC's processing block sizes correctly, including the first sample and scalar/control-rate inputs. Support in-place processing if framework assumptions permit.
- Use `float` audio I/O as specified by SC; consider double-precision state or coefficient calculations when clearly beneficial, but do not require a custom arbitrary-precision library.
- Prevent denormals/NaNs; never depend on accidental stability from a clipper on the final output. Preserve valid self-oscillation where model supports it; reject runaway digital behavior.
- No dynamic oversampling toggle inside a processing block. Introduce fixed 2× oversampling for **one nonlinear filter only if tests show significant benefit**, and measure added CPU. Do not add 4×/8×/16× globally.
- Determine parameter smoothing consciously: stable coefficient interpolation or a small internal smoothing mechanism when needed. Do not add an unrelated general smoothing framework.
- If an algorithm has materially different k-rate and a-rate processing costs, document the difference; prefer correct k-rate support first.

---

## 3. Minimal validation protocol (used for EACH selected UGen)

Use one small SC file per filter and, only if convenient, a small offline numerical checker. No test framework overhaul, no audio-quality metric suite.

**Basic checks** (all must be reported):

1. **Compile + load**: native binary compiles; SC class library compiles; boot `scsynth`; instantiate synth; confirm no unknown UGen or server crash.
2. **Three sources**: process a sawtooth (harmonic response), white/pink noise (spectral shaping), and impulse/short transient (time-domain stability). A sine at/near cutoff is useful for resonance.
3. **Three cutoff positions**: low (e.g. 100 Hz), mid (1 kHz), high (8 kHz at 48 kHz sampling), with moderate input level. Verify direction and basic shape of response.
4. **Resonance or equivalent**: minimum, middle, and high supported control settings; distinguish intended self-oscillation from numerical explosion.
5. **Modulation**: sweep each continuous control over its valid range without unexplained clicks, NaNs or huge gain spikes; test documented a-rate support only where implemented.
6. **Edge cases**: silence, repeated impulses, low sample-rate edge, zero/negative/out-of-range cutoff and resonance inputs; clamping must prevent undefined behavior. Test at least 44.1 and 48 kHz when possible; 96 kHz is useful but not an unconditional milestone blocker.
7. **Cost**: make one quick relative CPU measurement against an existing `RLPF`/`SVF`-style reference at the same number of active voices and block size; report setup and approximate result rather than enforcing one universal threshold.
8. **Specific test**: the filter's dedicated acceptance checks in §4–§7 below.

**Do NOT automatically build:** automated multiband LUFS, perceptual ABX apparatus, matching-to-hardware tests without hardware recordings, convolution analyzers, FFT spectrogram GUIs, a full CI benchmark matrix, or an extensive dataset. A **single** rendered audio file and a small response plot are optional debugging aids only, not mandatory artifacts.

**Numerical stop rule:** a compiling filter that occasionally outputs NaN/Inf, explodes from ordinary documented settings, or produces invalid pole positions is **not done**. Fix this before progressing to another UGen. A sonic mismatch without a reference recording should be identified as an open limitation, not silently fixed with arbitrary EQ.

---

## 4. Core implementations — exact agent instructions

### 4.1 `FSWasp`: EDP Wasp VCF — FIRST PRIORITY

**Source:** Köper, Holters, Esqueda and Parker, “A Virtual Analog Model of the EDP Wasp VCF,” DAFx 2022. See sources [R1]. **Read the paper before writing equations.**

**Crucial distinction:** the Wasp is **not** a generic saturated SVF. It is an OTA-controlled, CMOS-inverter-based, second-order multimode state-variable circuit, with nonlinear OTA and inverter characteristics, unusual signal levels, and feedback interactions. The cited paper studies a **Doepfer-derived version** with component/power differences from the historical EDP +5 V implementation. **Choose and label the modeled revision explicitly; do not blend component values from different revisions.**

**Stage W1 — small-signal reference and working UGen (mandatory first):**

1. Read paper §§2–3: identify signal flow, HP/BP/LP nodes, OTA transconductance control, inverter stages, resistor/capacitor network, and bias/AC-coupling behavior. Record selected circuit/revision and equation references in a brief source comment.
2. Implement the **paper-derived linearized** circuit (or derive its transfer function into a stable discrete state representation). Preserve actual signal inversion and HP/BP/LP relations. If simplifying the input AC-coupling network, note the approximation; avoid falsely claiming exact paper equivalence.
3. Choose one stable discretization (trapezoidal/TPT or validated state-space discretization). Derive the coefficient formula, don't paste an arbitrary cookbook biquad without tracing its relation to the circuit.
4. Public draft interface: `FSWasp.ar(in, freq=1000, res=0.2, drive=1, mode=0)`; mode = 0 LP, 1 BP, 2 HP, **init-only**. Keep drive unity in W1; it need not have an audible effect until nonlinear W2, or omit it until W2 if cleaner.
5. Check expected approximate 12 dB/octave two-pole magnitude slopes, resonance and output modes, with the paper's linear results where comparable.
6. Compile, run `examples/wasp_basic.scd`, and **STOP**. Do not attempt the nonlinear solver in W1.

**Stage W2 — circuit-informed nonlinear Wasp (separately authorized):**

1. Implement the paper's extended OTA transfer characteristic and CMOS inverter behavior **within** the filter's circuit equations, not merely at the output. Include diode/feedback components only if present in the chosen reference schematic/model.
2. Use the paper's discretization and nonlinear solution strategy or an independently derived equivalent; bounded Newton iteration only if required. For iterative solving, define a hard iteration cap, an initial guess from prior sample, a convergence check, and a finite, non-explosive fallback when convergence fails.
3. Keep the signal-level/drive scaling explicit and document what `drive=1` means. Do not apply a generic post-filter hard limiter to conceal solver instability.
4. Compare linear/nonlinear versions at low input (responses should broadly converge), then at higher drive (meaningful differences in harmonic generation and resonance compression). Test all modes.
5. Evaluate oversampling **only if** strong-drive aliasing is audible/measurable. 2× fixed may be considered; avoid implementing a library-wide oversampler.
6. Report whether model is Doepfer-derived or EDP-original, and what is not validated against hardware. **STOP** after W2.

**Acceptance:** meaningful LP/BP/HP behavior; stable frequency sweeps; nonlinear response occurs inside filter state/feedback; no unexplained NaNs; correct source/revision attribution. If nonlinear details cannot be reproduced responsibly, keep the linear `FSWasp` and label it as such—don't invent a circuit model.

### 4.2 `FSSteiner`: Steiner–Parker diode multimode VCF

**Sources:** choose a **specific** Steiner–Parker/Synthacon/Synthasystem circuit [R2]. Versions differ; “Steiner filter” alone is not a sufficient schematic.

1. Identify the exact topology: input injection points for LP/HP/BP, diode network, frequency-control mechanism, summing/feedback paths and component values. State whether it's an original/historical design, a documented modern adaptation or a topology-inspired approximation.
2. Map the linear/small-signal network first. Verify which input/output connection corresponds to each filter mode; do not simulate the three modes by substituting arbitrary output taps from a generic SVF.
3. Write the discrete filter using a stable equation (TPT or explicit circuit network). Model diode conductance/current *in situ* for the nonlinear version if sufficient information exists. Include a bounded solver if diode equations form an implicit loop.
4. Prototype interface `FSSteiner.ar(in, freq=1000, res=0.3, mode=0, drive=1)`; mode is init-only. Prefer one class to separate duplicate LP/BP/HP code.
5. Test differences among LP/BP/HP and peak behavior. Test resonance under input gain changes. Compare against a vanilla `RLPF` **to establish distinct behavior**, not to force spectral identity.
6. **Stop condition:** no credible selected circuit → implement one clearly labeled *linear topology reference* and report incomplete nonlinear emulation; do not invent a diode model.

**Acceptance:** modes actually reflect selected circuit routing; controlled nonlinear resonance; no severe numerical blowup during normal sweeps.

### 4.3 `FSPolivoks`: Formanta Polivoks VCF

**Source:** historical schematic and implementation context for K140UD12 programmable operational amplifiers [R3].

1. Inspect the documented schematic, identifying two programmable op-amp stages, their gain/current/slew limitations, resonance loop and actual available outputs (LP/BP). Do not silently add a high-pass mode if the chosen circuit does not supply it.
2. Stage P1: implement **linearized two-stage** behavior with `FSPolivoks.ar(in, freq=1000, res=0.3, mode=0, drive=1)` (mode only LP/BP if supported). Confirm tuning/resonance topology. **STOP.**
3. Stage P2 (separate request): introduce a bounded, physically motivated slew-rate/current limiting or op-amp dynamic law **inside the integrators**; slew limiting of an arbitrary post-filter output is not adequate. Avoid ungrounded hard-clipping values; expose one documented drive scaling, no 20-parameter op-amp simulator.
4. Run high-resonance and fast cutoff sweeps; verify that solver/integrator remains finite; compare P1/P2 to isolate model-specific effects.

**Acceptance:** documented LP/BP shape; demonstrable state-dependent slew/saturation; no invented hardware-calibration claim.

### 4.4 `FSZMorph`: original digital multi-resonant filter morphing

**Reference concept:** E-mu / Rossum Z-plane morphing [R4]. This is a **new original implementation**, not a port of their proprietary filter cubes, ROM or presets.

**M1 — minimum useful version:**

1. Define **two** original stable multiresonant filter configurations A/B. E.g., each uses 2–4 second-order sections to make obvious peaks/notches. Store a handful of **original** shape definitions in the C++ source; no external preset file format yet.
2. Select **parallel processing of A and B plus equal-gain crossfade** with `morph` in [0,1] for the first working version, because arbitrary coefficient interpolation can destabilize recursive filters. This is explicitly **response/output morphing**, not a claim of pole-zero or proprietary Z-plane interpolation. Document potential phase cancellation between A/B.
3. Draft interface: `FSZMorph.ar(in, morph=0, shapeA=0, shapeB=1)` where shape IDs are **init-only**; continuous `morph` may be modulated. Do not start with 14 poles, 280 presets, three dimensions or eight parallel responses.
4. Test endpoints (`morph=0` equals A; `morph=1` equals B), continuous sweep and coefficient stability at sample rates 44.1/48k. Ensure useful and distinct tonal movement.
5. **STOP**; only expand to 2D four-corner morphing after a successful M1 demo and explicit approval. 3D/eight-corner mode is a *later* optional milestone, with CPU evaluation before implementation.

**Acceptance:** 2 distinct original complex responses, stable interpolation, no borrowed proprietary presets, clear explanation of what the interpolation does and does not do.

### 4.5 `FSDispersion`: dispersive all-pass / group-delay filter

**Reference:** Abel and Smith (DAFx 2006) [R5]. Avoid assuming implementation of the entire high-order optimization method is necessary to obtain a useful filter.

1. Begin with a cascade of **four** stable second-order digital all-pass sections (or a similarly small fixed configurable count). Each section should have poles strictly within the unit circle; zeros reciprocally related to poles.
2. Use parameters that have a coherent physical meaning: `center`, `spread`, `q`, with a fixed section count at initialization. Map center/spread deterministically to distributed all-pass section frequencies. State whether the target is a general disperser or approximate stiffness/spring-like dispersion.
3. Draft interface `FSDispersion.ar(in, center=1500, spread=1.0, q=2.0)`; avoid a `wet` control in the initial version, because dry/wet mixing destroys a pure all-pass magnitude response.
4. Verify **approximately flat magnitude** for static coefficients; explicitly check phase/group delay varies with frequency. Test an impulse to observe temporal dispersion. Check fast parameter sweeps separately; a time-varying all-pass is not strictly magnitude-preserving during modulation.
5. Use simple section design first. Only if the user explicitly wants a target group-delay curve should the agent implement a high-order group-delay fitting method or arbitrary user-defined curve.

**Acceptance:** stable all-pass behavior with static unit magnitude to numerical tolerance, audible impulse spreading, bounded modulation artifacts. Stop after one version.

---

## 5. Second-wave implementations — ONLY when requested

### 5.1 `FSRolandOTA`: IR3109-style four-stage OTA filter

**Reference:** IR3109/AS3109 architectural and specific instrument circuit comparisons [R6].

- Choose **one** documented IR3109 application circuit first, rather than combining Juno, Jupiter and SH-101 characteristics. Record stage selection, feedback tap, resonance and relevant gain behavior.
- Implement a stable four-stage OTA-cascade approximation with feedback topology tied to that circuit. First deliver an audible functional model; add nonlinear OTA stage behavior only where source evidence and results justify it.
- Draft `FSRolandOTA.ar(in, freq=1000, res=0.3, drive=1)`; no multi-synth mode selector in v1.
- Test low-pass slope, feedback/self-oscillation behavior (if source circuit supports it), gain through cutoff sweeps, and compared response against `VogueLadderCh`/`MoogFF`.
- **Go/no-go:** if the result is an indistinguishable generic ladder, defer rather than shipping an inaccurately named Roland emulation.

### 5.2 `FSCS80`: independently resonant HP and LP combination

**Reference:** Yamaha CS-80 owner/service manuals [R7].

- Implement an HP stage and LP stage **in series**, each with its own cutoff and resonance; use stable 2-pole structures matching chosen documented response as closely as practical. State if circuit-exact IC behavior is not modeled.
- Draft `FSCS80.ar(in, hpFreq=100, hpRes=0.2, lpFreq=8000, lpRes=0.2)`.
- Confirm HP control suppresses lows, LP suppresses highs, two resonant regions can coexist, and overlapping cutoff sweeps produce narrow passbands. Handle HP cutoff above LP cutoff sanely (strong attenuation is normal, not a failure).
- Keep this a **topology-inspired** filter unless a specific verified Yamaha circuit is implemented. No full CS-80 voice, envelopes, aftertouch, or instrument emulation.

### 5.3 `FSChipVCF`: select SSM2044 **or** CEM3320

- **Research gate, max one focused pass:** choose a publicly documented chip application and datasheet/schematic. Compare with `ARPFilterCh` and current LADDER/SVF options; identify one unique control response or internal topology.
- If no credible circuit evidence exists, **SKIP**. Do not ship an arbitrary four-pole resonant cascade branded as a chip emulation.
- If credible: choose a single chip and a single application circuit; implement its stage architecture, gain and resonance arrangement. Add only one targeted nonlinearity if physically justified. Draft `FSChipVCF.ar(in, freq, res, drive)`; rename public class if a more accurate chip-specific name is appropriate.
- Validate low-pass slope, resonance response, nonlinear staging and distinctness. Do not implement both chips in the same milestone.

### 5.4 `FSNLMS`: adaptive normalized LMS FIR

- This is a **digital adaptive filter**, not an analog VCF. Implement the standard NLMS update with two audio signals: `reference` (filter input) and `desired` (target). Define error `e[n] = desired[n] − y[n]`, and update taps by `mu * e[n] * xvec/(epsilon + ||xvec||²)` with bounded `mu` and positive `epsilon`.
- First version: fixed small tap count chosen at init (e.g. 32); no FFT partitioning, no echo-cancellation system, no dynamic arrays in audio processing.
- Output at least the **estimated** response `y` and **error** `e`; use SC's appropriate multi-output UGen convention if readily supported. Carefully define how SC wrapper exposes the two outputs.
- Add one tiny demonstration: identify a short known FIR from noise, show error decreases; report behavior with `mu=0` and silent reference. Guard low-denominator cases.
- Do not automatically add RLS, frequency-domain adaptation, neural adaptation, noise reduction, or feedback suppression products.

### 5.5 `FSFormantMorph`: coordinated formant filter bank

- Compare `Formlet`, `FormantTable`, `Gammatone`, and ordinary BP banks; only proceed if coordinated envelope interpolation is useful.
- Begin with **three** parallel resonant sections and **two** original fixed formant configurations, interpolating center frequencies in log-frequency, bandwidths in a stable positive parametrization, and gains in a documented domain.
- Draft `FSFormantMorph.ar(in, morph=0, freqScale=1, bandwidthScale=1)` with the two configurations fixed for v1. Later selectable vowel banks are optional; no sample database or buffer-managed preset loader.
- Check endpoints, level behavior under sweeping, and stability near Nyquist. Avoid claiming detailed vocal-tract physical modeling.

### 5.6 `FSVCFQ`: Serge-style variable-Q / ping response

- First inspect documented Serge VCFQ functions [R8]: dynamically controlled Q, multimode output, and trigger-excited ringing. **Verify these can't be adequately obtained by patching a conventional resonator/SVF with a trigger.**
- If there is no materially distinct internal behavior supported by documentation, **SKIP** and provide an `.scd` example of an existing filter being pinged instead.
- If justified, implement one stable model with demonstrable variable-Q/trigger response, not a complete Serge module with gain stages, extended modulation ranges and custom input AGC all at once.
- Limit interface to `in, freq, q, trig, mode`; tests: impulse-induced damped oscillation with Q/frequency control and normal filtered operation.

### 5.7 `FSDynamicSOS`: modulation-safe general recursive filter

- **Evidence gate:** inspect existing `SOS`, `IIRFilter` and SC coefficient modulation behavior. Show one concrete real-time use where the existing implementation is insufficient. If not demonstrable, **SKIP**.
- Select one approach (e.g. cascade of topology-preserving SVF sections with stable parameters, or constrained pole/zero interpolation). **Do not linearly interpolate arbitrary SOS coefficients without checking stability.**
- Implement two SOS stages maximum in first version, with a small parameter interface; no general-purpose runtime filter-design scripting engine.
- Test fast cutoff/Q movement, pole stability, sample-rate changes, and finite output under stress. Only then consider additional sections.

---

## 6. GitHub compiled-plugin packaging — AFTER first working UGen

**Do not implement CI/release infrastructure before a local plugin works.** This is one short infrastructure milestone after at least one UGen passes tests.

1. Inspect existing packaging in the repository. Reuse build scripts if they already successfully generate native SC extensions. Otherwise use CMake following SuperCollider's plugin examples [R9].
2. First prove build on the developer's active machine, especially **macOS Apple Silicon**. Also support Linux x86_64 if the build environment is available. Add Windows only when an actual Windows native build and SC load test can be performed; do not claim three-platform support based only on cross-platform-looking source.
3. A GitHub Actions job, **if needed**, should build on a version-tag event and upload the compiled server plugin, matching `.sc` classes and concise README/example into a per-platform archive. Reuse an existing workflow rather than duplicating one.
4. Include the **native binary** expected by SC for each OS, not just source files. Use the SuperCollider platform's correct binary extension and directory conventions; avoid hardcoding one platform's file suffix.
5. The user installs by unzipping/copying the supplied extension directory into the path reported by `Platform.userExtensionDir`, recompiling the class library and restarting the server as necessary. No Quark install.
6. Name and document the minimum supported SuperCollider version; verify the ABI/build source version as appropriate. Do not promise universal macOS binaries unless both architectures actually ship and were tested.
7. Each GitHub release should include: compiled extension(s), `.sc` wrappers, a short install note, one minimal `.scd` example per implemented UGen, and the upstream attribution/license files required by actual code dependencies.
8. Do not add code signing, installers, notarization, Docker images, VST/AU targets, automatic documentation deployment, app stores or distribution telemetry.

**Possible install skeleton (adapt to actual builds):**

```
FilterSuite-<version>-macos-arm64/
  Extensions/
    FilterSuite/
      <compiled-plugin-file>
      Classes/
        FSWasp.sc
        ...
      HelpSource/Classes/    # only completed, concise files
      ...
  README-INSTALL.txt
```

If repository already follows a different working archive layout, do not change it merely to match this illustration.

---

## 7. Gemini Flash High: operating protocol / anti-token-waste guardrails

Gemini Flash High should act as an **implementation engineer on a bounded ticket**, not an independent product architect. It may make local engineering decisions but **must not expand the ticket**.

### Before each ticket

Read (1) the ten prime directives, (2) *only* the chosen filter's instructions and relevant references, (3) the repository's relevant existing source/build files. **Do not reread every paper and all 12 implementations in each step.**

State in no more than **six lines**:
- Which single milestone is being implemented?
- Exact source/reference or why this is an original digital design.
- Files expected to change (approximate).
- Numerical strategy and likely stability risk.
- Concrete test to run.
- Explicitly excluded tasks.

Then code. Avoid lengthy architectural debates or optional enhancements unless blocked by a real mathematical question.

### During coding

- Prefer a **small complete implementation** over a long to-do list or simulation scaffolding.
- Compile early, fix the specific compiler/runtime error, rerun the relevant test. Do not rewrite unrelated code while fixing an error.
- Don't add helper abstractions unless the same code is needed by two **existing** UGens, not two imagined future ones.
- One meaningful source file and one wrapper are acceptable for a UGen. File count is not a performance metric.
- Never use a fake/demo DSP process that differs from the shipping native UGen and report it as a pass.
- Do not change names/API without recording the breaking change.
- Do not silently reduce circuit fidelity to make the code run. Explain the approximation and, if needed, stop at a stable linear model.

### Finish behavior

Stop when tests pass. Emit the short milestone report from §0 and **wait for the next instruction**. Do not begin a second filter, add extras, prepare a giant README, or undertake “Phase 2 improvements” automatically.

### User prompts to paste into the coding agent

**Prompt A — one-time repo audit:**

> Read `FilterSuite_SC_Agentic_Plan.md`, especially §§0–3 and §7. Inspect the **current repo only** and report build commands, existing UGens, the completed MS-20 implementation, naming collisions, and smallest necessary first code change. Do **not** implement a filter or refactor anything yet. Keep your output brief and stop.

**Prompt B — implement first Wasp stage:**

> Follow `FilterSuite_SC_Agentic_Plan.md`. Implement **only §4.1 Stage W1 (`FSWasp` linear small-signal)**, using the cited DAFx paper and the repository's existing build conventions. Compile and test in scsynth with LP/BP/HP modes, cutoff and resonance sweeps. No nonlinear stage W2, no other filter, no oversampling, no GUI, no Quark, no new CI. Use the mandated short report and stop.

**Prompt C — implement nonlinear Wasp later:**

> Review the completed `FSWasp` W1 implementation and implement **only §4.1 Stage W2**. Use the selected circuit revision and documented component nonlinearities inside the OTA/CMOS/feedback equations. Run bounded numerical solves and compare W1/W2 at quiet/high drive. Report any unvalidated physical assumptions. Do not touch other filter models; stop when verified.

**Prompt D — next selected filter template:**

> Work on **only `[EXACT CLASS / STAGE]`**, following the corresponding subsection of `FilterSuite_SC_Agentic_Plan.md`. Inspect existing code; derive the filter-specific equations from the cited source; write the native UGen and minimal `.sc` wrapper; compile, run the targeted `.scd` smoke tests, and report results in the prescribed format. Do not make unrelated infrastructure or other UGens. Stop.

**Prompt E — GitHub binary release after local success:**

> Implement **only §6**. Reuse the current native CMake/build scripts; package the **already implemented and tested** UGens as compiled SuperCollider extensions for verified target platforms using GitHub Releases. Include `.sc` wrappers and minimal examples. No Quark, installers, GUI, plugin-format ports, or unrelated CI. Report actual build/test support and stop.

---

## 8. Focused reference bibliography (read only the chosen filter's sources)

Sources are given as *starting points*. Verify primary schematics, revisions, algorithms, and actual upstream code licensing before reuse.

- **[R1] EDP Wasp model:** Köper, L., Holters, M., Esqueda, F. & Parker, J. D. (2022), *A Virtual Analog Model of the EDP Wasp VCF*, DAFx. https://www.dafx.de/paper-archive/2022/papers/DAFx20in22_paper_34.pdf — Particularly important: Doepfer-derived values vs original EDP power/component choices.
- **[R2] Steiner–Parker source/circuit:** Analogue Realities Steiner–Parker VCF documentation: https://analoguerealities.com/projects/voltage-controlled-filter/ — Check exact historical/modern variant before deriving equations.
- **[R3] Polivoks schematic:** https://github.com/clarionut/Polivoks_filter — Contains historical schematic reference and modern adaptation; cross-check K140UD12 characteristics.
- **[R4] Z-plane concept:** Rossum Electro-Music, *Morpheus*: https://www.rossum-electro.com/products/morpheus/ — Describes 14-pole proprietary multi-filter cubes, **not** an authorization to reproduce presets or a ready-made coefficient interpolation algorithm.
- **[R5] Dispersive allpass:** Abel, J. S. & Smith, J. O. (2006), *Robust Design of Very High-Order Allpass Dispersion Filters*, DAFx: https://www.dafx.de/paper-archive/2006/papers/p_013.pdf — For later advanced matching of prescribed group delay; basic section cascade comes first.
- **[R6] IR3109 circuits:** Electric Druid, *Roland filter designs with the IR3109 or AS3109*: https://electricdruid.net/roland-filter-designs-with-the-ir3109-or-as3109/ — Select one specific application variant.
- **[R7] Yamaha CS-80 manual:** https://synthfool.com/docs/Yamaha/CS_Series/Yamaha%20CS-80%20Owners%20Manual.pdf ; service design material: https://rcarchives.com/m/YamahaCSSeriesSynthesizerServicingGuidePOSTED.pdf — Distinguish interface/function from component-exact circuit.
- **[R8] Serge variable-Q filter:** https://serge.sublevel9.net/p/voltage-controlled-filters.html ; https://www.elby-designs.com/webtek/cgs/serge/cgs512/cgs512.htm — Compare capabilities against existing SVF/ping patches before implementing.
- **[R9] SuperCollider server plugin build:** https://github.com/supercollider/supercollider/wiki/Plugins-development ; https://github.com/supercollider/cookiecutter-supercollider-plugin ; https://github.com/supercollider/sc3-plugins — Existing repository conventions take precedence.
- **[R10] Existing SC filter overlap:** https://github.com/madskjeldgaard/portedplugins — `VAKorg35`, `VASEM12`, `VADiodeFilter`, `VadimFilter`, etc.
- **[R11] Your existing ChowDSP ports:** https://github.com/fmiramar/chowdsp-sc-ports — Audit `SallenKeyCh`, `WernerCh`, `WarpCh`, `ARPFilterCh`, etc. for overlap; do not modify this repo unless it is the intended FilterSuite repository.
- **[R12] Comparative experimental implementations:** https://github.com/JoepVanlier/FiltherManual — A useful reference for varied filter ideas and nonlinear positions; **not** automatically licensed for copy/paste.
- **[R13] Wave digital circuit algorithms:** https://github.com/Chowdhury-DSP/chowdsp_wdf — Consult only if a chosen diode/transistor circuit requires WDF; **no global WDF framework by default**.
- **[R14] Stable VA discretization:** https://cytomic.com/technical-papers/ — Trapezoidal/TPT SVF and other useful design references.

---

## 9. FINAL CHECKLIST: what should *not* happen

- [ ] No MS-20 reimplementation; it is done.
- [ ] No Quark, `.quark` file, Quarks metadata or Quarks distribution instructions.
- [ ] No unrelated MIR, FFT suite, LUFS metering, scope, GUI, plotting dashboard, synthesizer voice or audio effect chain.
- [ ] No simultaneous code generation for all 12 models.
- [ ] No “faithful analog emulation” claims when only a linear topology was reproduced.
- [ ] No unbounded nonlinear solvers, accidental crashes or per-sample heap allocation.
- [ ] No unnecessary third-party DSP framework dependencies or complex continuous integration before a local binary works.
- [ ] No copying protected preset ROMs or incompatible upstream code.
- [ ] No claim that a build, audio validation or GitHub release was completed unless it was actually done.
- [ ] No finishing a ticket by starting a new ticket without explicit user instruction.

**Success criterion:** a small GitHub repository of genuinely distinct, well-behaved **compiled SuperCollider filter UGens**, built and validated one by one, with clear provenance and no infrastructure sprawl.
