# Filtra — A SuperCollider UGen Suite for Filter and Resonance

![Filtra Banner](Filtra%20Banner.png)

A physically informed, historically authentic suite of real-time SuperCollider server UGens modeling classic vintage synthesizer filters and original digital virtual analog topologies.

Distributed as native compiled binaries for SuperCollider via **GitHub Releases** (no Quark package manager needed).

---

## Included Filter Models

### 1. Expanded Virtual Analog & Digital Filter Models

| UGen | Circuit / Architecture | Linearity | Features & Modes | Sonic Character |
|---|---|---|---|---|
| **`CS80`** | Yamaha CS-80 Series (IG00153 / IG00156) | Nonlinear (inter-stage soft sat) | Series HP $\to$ LP (4-pole total); independent HP & LP controls | Iconic dual-resonant formant peaks, vocal vowel cavities, classic Vangelis sweeps. |
| **`RolandOTA`** | Roland IR3109 (Juno-60 / Jupiter-8 / SH-101) | Nonlinear (OTA differential tanh) | 4-pole Low-Pass (-24 dB/oct); `resComp` bass recovery | Liquid singing limit cycle, authentic Roland bass drop with switchable compensation. |
| **`ChipVCF`** | SSM2044 / CEM3320 4-Pole Ladder (Polysix, Prophet-5) | Nonlinear (differential gain cell sat) | 4-pole Low-Pass (-24 dB/oct); `resComp` bass recovery | Classic 80s polyphonic synth character, punchy bass, autonomous limit cycle. |
| **`NLMS`** | Adaptive Normalized LMS FIR Filter | Real-time adaptive transversal FIR | 32-tap normalized LMS; dual multi-output `[estimated, residualError]` | Real-time echo cancellation, acoustic feedback suppression, system identification. |
| **`FormantMorph`** | Coordinated Multi-Formant Vowel Bank | Linear parallel 2-pole TPT resonators | 3 parallel formants; continuous log-frequency morphing across 5 vowels ([a, e, i, o, u]) | Organic human singing diphthongs and vowel sweeps without clicks or volume drops. |
| **`VCFQ`** | Serge Variable-Q Modular Filter & Resonator Core | Nonlinear (diode AGC feedback) | LP, BP, HP, Notch; dedicated trigger/impulse ping input | Classic Serge acoustic percussion pinging, ringing bells, marimbas, dynamic Q sweeps. |
| **`DynamicSOS`** | Modulation-Safe Cascaded Biquad | Linear continuous physical TPT states | 7 Modes (LP, HP, BP, Notch, Peak EQ, LowShelf, HighShelf); 4-pole steepness | Artifact-free, click-free audio-rate sweeps and stepped coefficient jumps with zero transient blowup. |
| **`Wasp`** | EDP Wasp (CA3080 OTA + CD4069 CMOS Inverters) | Nonlinear (implicit NR solver) | LP, BP, HP (12 dB/oct); analytical damping pot network | Brash, dirty, aggressive CMOS soft-saturation and OTA limiting (Köper et al., DAFx 2022). |
| **`Steiner`** | Steiner–Parker Multimode Diode VCF | Nonlinear (diode feedback limiter) | LP (-12 dB/oct), BP (symmetric), HP (+6 dB/oct zero); multi-input injection | Raw diode variable resistance, singing self-oscillation limit cycle (Steiner, 1974; YuSynth). |
| **`Polivoks`** | Formanta Polivoks VCF (K140UD12 / µA776) | Nonlinear (op-amp transconductance + rail sat) | LP (12 dB/oct), BP (6 dB/oct); exact hardware modes | "Capacitor-less" programmable op-amp slew/transconductance saturation and scream (Kuzmin, 1982). |
| **`ZMorph`** | Original Digital Multiresonant Filter Morphing | Linear parallel TPT banks | 4-section parallel TPT SVF banks; 6 built-in vocal & metallic presets | Equal-gain continuous response morphing with guaranteed stability (inspired by Rossum Z-plane). |
| **`Dispersion`** | Dispersive All-Pass Group-Delay Filter | Linear TPT all-pass cascade | 4 cascaded 2nd-order all-pass sections; geometric frequency spread | Exactly flat magnitude ($|H| \equiv 1.0$), Parseval energy conservation, acoustic stiffness and laser chirps (Abel & Smith, DAFx 2006). |

### 2. Korg MS-20 Suite (`MS20*`)

| UGen | Architecture | Linearity | Damping | Sonic Character |
|---|---|---|---|---|
| **`MS20SK`** | Sallen–Key Biquad (TDF-II) | Linear | $(3 - K)$ | Textbook reference, loaded RC damping, authentic $+6\text{ dB/oct}$ HP. |
| **`MS20TPT`** | Zero-Delay Feedback (TPT/ZDF) | Linear | $(3 - K)$ | Physical capacitor states ($v_{C1}, v_{C2}$) with artifact-free audio FM. |
| **`MS20Diode`** | Korg-35 Forward Diode Limiter | Nonlinear (NR solver) | Dynamic | Raw, gritty distortion; forward amplifier diodes clip full spectrum. |
| **`MS20OTA`** | KLM-307 Dual OTA (Buffered) | Nonlinear | $(2 - K)$ | Liquid, singing resonance; diodes in feedback saturate only the peak. |
| **`MS20Circuit`** | Discrete BJT MNA Circuit Model | Nonlinear (2x2 NR) | Dynamic | Reverse-saturation BJT pair with prominent 2nd harmonic (even) growl. |

*(All MS-20 nonlinear models support optional internal 2x polyphase half-band oversampling via `oversample: 1`).*

---

## Installation via Precompiled GitHub Release

1. Download the precompiled archive for your platform from the **GitHub Releases** page:
   - macOS (Apple Silicon arm64): `Filtra-0.1.0-macos-arm64.zip`
   - Linux (x86_64): `Filtra-v0.1.0-linux-x86_64.zip`
   - Windows (x64): `Filtra-v0.1.0-windows-x64.zip`
2. Open SuperCollider and locate your user extensions folder:
   ```supercollider
   Platform.userExtensionDir.postln;
   ```
   *(macOS typical: `~/Library/Application Support/SuperCollider/Extensions`)*
3. Unzip and copy the enclosed `Extensions/Filtra` directory into your Extensions folder.
4. In SuperCollider, recompile the class library:
   - Menu: **Language -> Recompile Class Library** (or `Cmd + Shift + L` / `Ctrl + Shift + L`).
5. Boot the server (`Cmd + B` / `Ctrl + B`) and explore the scripts in `examples/` or the in-app guide (`Guides/Filtra`).

---

## Quick Start Examples

### 1. EDP Wasp VCF Sweep
```supercollider
{
    var src = Saw.ar([110, 110.5]) * 0.25;
    var cutoff = SinOsc.kr(0.2).exprange(150, 6000);
    Wasp.ar(src, freq: cutoff, res: 0.7, drive: 2.0, mode: 0) * 0.4;
}.play;
```

### 2. Steiner-Parker Diode Multimode
```supercollider
{
    var src = Pulse.ar([80, 80.5], 0.3) * 0.2;
    var cutoff = LFTri.kr(0.15).exprange(200, 5000);
    Steiner.ar(src, freq: cutoff, res: 0.85, mode: 1, drive: 1.5) * 0.4;
}.play;
```

### 3. Formanta Polivoks Screaming Resonance
```supercollider
{
    var src = Saw.ar(55) * 0.25 ! 2;
    var cutoff = SinOsc.kr(0.25).exprange(200, 4500);
    Polivoks.ar(src, freq: cutoff, res: 0.95, mode: 0, drive: 2.0) * 0.35;
}.play;
```

### 4. Z-Plane Filter Morphing (Vowel A -> Vowel I)
```supercollider
{
    var src = Saw.ar([110, 110.5]) * 0.25;
    var morph = SinOsc.kr(0.2).range(0.0, 1.0);
    ZMorph.ar(src, morph: morph, shapeA: 0, shapeB: 1) * 0.5;
}.play;
```

### 5. Acoustic Dispersion (Laser Twang / Phase Smear)
```supercollider
{
    var trig = Impulse.ar(3);
    var sig = Dispersion.ar(trig, center: 1800, spread: 1.5, q: 4.0);
    sig * 0.4 ! 2;
}.play;
```

---

## Building from Source

### Prerequisites
- SuperCollider $\ge$ 3.10 (tested with 3.14.1)
- CMake $\ge$ 3.16
- C++17 compliant compiler (AppleClang, GCC, Clang, MSVC)

```bash
mkdir build && cd build
cmake .. -DSC_PATH=/path/to/supercollider/headers
cmake --build . --config Release
cmake --install .
```

---

## Verification Test Suites

All 17 UGens are accompanied by automated headless test suites verifying mathematical accuracy, asymptotic slopes, Newton-Raphson solver convergence, audio-rate FM, and regression stability:

```bash
sclang tests/test_cs80.scd          # 6/6 tests pass (Yamaha CS-80)
sclang tests/test_roland_ota.scd    # 6/6 tests pass (Roland IR3109 OTA)
sclang tests/test_chip_vcf.scd      # 5/5 tests pass (SSM2044 ChipVCF)
sclang tests/test_nlms.scd          # 4/4 tests pass (Adaptive NLMS FIR)
sclang tests/test_formant_morph.scd # 4/4 tests pass (FormantMorph Bank)
sclang tests/test_vcfq.scd          # 5/5 tests pass (Serge VCFQ Ping Resonator)
sclang tests/test_dynamic_sos.scd   # 5/5 tests pass (Modulation-Safe DynamicSOS)
sclang tests/test_wasp.scd          # 15/15 tests pass (EDP Wasp)
sclang tests/test_steiner.scd       # 15/15 tests pass (Steiner-Parker)
sclang tests/test_polivoks.scd      # 12/12 tests pass (Formanta Polivoks)
sclang tests/test_zmorph.scd        # 9/9 tests pass (ZMorph)
sclang tests/test_dispersion.scd    # 12/12 tests pass (Dispersion)
sclang tests/test_oversampling.scd  # 12/12 tests pass (MS-20 2x oversampling)
```

Total: **110 / 110 automated unit tests pass.**

---

## Academic References & Sources

See [`SOURCES.md`](SOURCES.md) for exhaustive circuit schematics, continuous-time transfer function derivations, trapezoidal TPT nodal equations, and academic citations.

## License

GNU General Public License v3.0 or later ([GPL-3.0-or-later](LICENSE)).
SuperCollider is free software developed by the SuperCollider community.
