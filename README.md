# MS-20 Filter Suite for SuperCollider

A physically informed, historically authentic suite of real-time SuperCollider UGens modeling both the early Korg-35 and later KLM-307 OTA revisions of the legendary Korg MS-20 synthesizer filter.

## Features & Implemented Models

| Model | Architecture | Linearity | Damping | Self-Oscillation | Sonic Character |
|---|---|---|---|---|---|
| **`MS20SK`** | Sallen–Key Biquad (TDF-II) | Linear | $(3 - K)$ | Bounded ($Q < 20$) | Textbook linear reference, mutual RC loading, pristine response. |
| **`MS20TPT`** | Zero-Delay Feedback (TPT/ZDF) | Linear | $(3 - K)$ | Bounded ($Q < 20$) | Preserves circuit graph and physical capacitor voltages ($v_{C1}, v_{C2}$). |
| **`MS20Diode`** | Korg-35 Forward Diode Limiter | Nonlinear | Dynamic | Bounded Limit Cycle | Raw, gritty, full-spectrum distortion; forward diodes clip all frequencies. |
| **`MS20OTA`** | KLM-307 Dual OTA (Buffered) | Nonlinear | $(2 - K)$ | Bounded Limit Cycle | Transparent, singing resonance; diodes in feedback saturate only the peak. |
| **`MS20Circuit`** | Discrete BJT MNA Circuit Model | Nonlinear | Dynamic | Bounded Limit Cycle | Reverse-saturation BJT pair; prominent asymmetric 2nd harmonic (even) distortion. |

### Key Architectural Highlights
- **Authentic MS-20 High-Pass Topology (6 dB/octave):** In the physical MS-20, high-pass mode grounds the LP input and injects audio into lifted capacitor $C_2$. This yields an asymptotic 6 dB/octave slope below cutoff with a 2nd-order resonance peak, faithfully reproduced in all five models (`mode = 1`).
- **Sample-Accurate Audio-Rate Modulation (Filter FM):** All models support both control-rate (`kr`) and audio-rate (`ar`) `freq` modulation for audio-rate filter FM without block-boundary artifacts.
- **Physical Non-Linearities:** Active anti-parallel diodes are placed at their authentic circuit locations (forward amplifier in `MS20Diode` & `MS20Circuit`, resonance feedback path in `MS20OTA`). `MS20Circuit` additionally models the nonlinear, asymmetric conductance of the reverse-saturated BJT transistors ($Q_1, Q_2$), generating authentic 2nd-order harmonic growl.
- **Optional 2x Polyphase Half-Band Oversampling:** All nonlinear models (`MS20Diode`, `MS20Circuit`, `MS20OTA`) provide an optional internal 2x oversampling mode (`oversample: 1`) using an elliptic 2-path polyphase allpass filter (> 70 dB stopband rejection, < 0.0005 dB ripple) to eliminate foldover aliasing during extreme overdrive and audio-rate FM.
- **Quark Ready:** Includes `MS20Filters.quark` metadata for seamless distribution and installation via the SuperCollider Quark package manager.

---

## Quick Start & Audition

### 1. Interactive Studio GUI
Open and run `examples/MS20_Audition_GUI.scd` in the SuperCollider IDE for a visual studio featuring real-time `FreqScopeView` (spectrum) and `ScopeView` (oscilloscope), model switching, drive control, and dual-filter serial routing:

```supercollider
// Run inside SuperCollider IDE
"examples/MS20_Audition_GUI.scd".loadRelative;
```

### 2. Complete Audition Demo
Run `examples/MS20_Complete_Audition.scd` to hear direct A/B/C/D model comparisons, autonomous limit-cycle self-oscillation, audio-rate FM, and the authentic dual-filter serial patch (`HP -> LP`):

```supercollider
"examples/MS20_Complete_Audition.scd".loadRelative;
```

### 3. Minimal Code Example
```supercollider
// Authentic MS-20 Dual-Filter Serial Patch (HPF -> LPF)
(
{
    var src = (Saw.ar(55) + Saw.ar(55.25)) * 0.4;
    // Stage 1: Authentic MS-20 High-Pass (mode = 1)
    var hp  = MS20Diode.ar(src, freq: 160, res: 0.4, drive: 1.5, mode: 1);
    // Stage 2: Authentic MS-20 Low-Pass (mode = 0)
    var lp  = MS20Diode.ar(hp, freq: XLine.kr(6000, 250, 6), res: 0.6, drive: 1.5, mode: 0);
    (lp * 0.25) ! 2
}.play;
)
```

---

## Build and Installation

### Prerequisites
- SuperCollider $\ge$ 3.10 (tested with 3.14.1)
- CMake $\ge$ 3.14
- C++17 compliant compiler (Clang, GCC, MSVC)

### Build Instructions
```bash
mkdir build && cd build
cmake ..
cmake --build .
cmake --install .
```
Extension files are automatically installed into your user SuperCollider Extensions directory:
- **macOS:** `~/Library/Application Support/SuperCollider/Extensions/MS20Filters`
- **Linux:** `~/.local/share/SuperCollider/Extensions/MS20Filters`
- **Windows:** `%LOCALAPPDATA%/SuperCollider/Extensions/MS20Filters`

---

## Verification & Test Suite

The suite comes with comprehensive numerical and SuperCollider test suites:

```bash
# Analytical pole stability, asymptotic slope checks, and self-oscillation RMS
python3 tests/verify_numerical.py

# Milestone 1: Linear Sallen-Key Verification
sclang tests/test_ms20sk.scd

# Milestone 2: ZDF/TPT Equivalence Null-Test
sclang tests/test_ms20tpt.scd

# Milestone 3: Korg-35 Forward Diode Nonlinearity & Limit Cycle
sclang tests/test_ms20diode.scd

# Milestone 4: KLM-307 Dual OTA Passband Immunity & Resonance Limiting
sclang tests/test_ms20ota.scd

# Milestone E: Transistor / Circuit Model (Reverse-Saturation BJT & 2nd Harmonic)
sclang tests/test_ms20circuit.scd

# Option A: Sample-Accurate Audio-Rate FM Verification
sclang tests/test_audio_rate_fm.scd

# Tier 5: 2x Polyphase Half-Band Oversampling Verification
sclang tests/test_oversampling.scd
```

---

## References

1. Timothy E. Stinchcombe (2006/2009), *A Study of the Korg MS10 & MS20 Filters*, §§2, 4, 5, 7.
2. Will Pirkle (2013), *Virtual Analog Korg35 Highpass Filter Simplified*, App Note 7A, v2.0.
3. Vadim Zavalishin (2012), *The Art of VA Filter Design*.
