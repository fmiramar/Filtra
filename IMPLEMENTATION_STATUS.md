# FilterSuite Implementation Status

| Filter | Proposed Class | Status | Reason / Summary |
|---|---|---|---|
| **Korg MS-20 Sallen-Key** | `MS20SK` | **passed** | Linear Sallen-Key biquad with loading $(3-K)$ and authentic $+6\text{ dB/oct}$ HP. |
| **Korg MS-20 TPT/ZDF** | `MS20TPT` | **passed** | 2x2 zero-delay state-space capacitor solver with audio-rate FM. |
| **Korg MS-20 Diode** | `MS20Diode` | **passed** | Forward amplifier diode limiter with Newton-Raphson solver and 2x oversampling. |
| **Korg MS-20 OTA** | `MS20OTA` | **passed** | KLM-307 buffered dual-OTA filter with feedback limiter and 2x oversampling. |
| **Korg MS-20 Circuit** | `MS20Circuit` | **passed** | Discrete BJT MNA model with reverse-saturation 2nd harmonic and 2x oversampling. |
| **EDP Wasp VCF** | `FSWasp` | **passed** | Stages W1 & W2 complete: Linear small-signal & circuit-informed nonlinear OTA/CMOS model verified (LP/BP/HP, 12 dB/oct slopes, DAFx 2022). |
| **Steiner-Parker VCF** | `FSSteiner` | **not started** | Core candidate 2; diode multimode routing. |
| **Formanta Polivoks VCF** | `FSPolivoks` | **not started** | Core candidate 3; programmable op-amp K140UD12 integrator model. |
| **Z-Plane Morph** | `FSZMorph` | **not started** | Core candidate 4; original parallel multiresonant response morphing. |
| **Dispersive All-Pass** | `FSDispersion` | **not started** | Core candidate 5; cascaded second-order all-pass group delay spreading. |
| **Roland OTA Cascade** | `FSRolandOTA` | **not started** | Later candidate; IR3109 four-stage cascade. |
| **Yamaha CS-80 Pair** | `FSCS80` | **not started** | Later candidate; serial independently resonant HP $\to$ LP pair. |
| **SSM2044 / CEM3320** | `FSChipVCF` | **not started** | Conditional gate; subject to unique topology evaluation. |
| **Normalized LMS FIR** | `FSNLMS` | **not started** | Later candidate; adaptive FIR filter. |
| **Formant Morph Bank** | `FSFormantMorph` | **not started** | Later candidate; coordinated resonant vowel interpolation. |
| **Serge Variable-Q** | `FSVCFQ` | **not started** | Conditional gate; verify distinctness against standard pinged SVF. |
| **Dynamic SOS** | `FSDynamicSOS` | **not started** | Conditional gate; verify concrete modulation need beyond SOS. |
