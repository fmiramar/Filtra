// =====================================================================
// MS20Circuit_demo.scd: Transistor / Circuit Modeling Demonstration
// Demonstrates:
// 1. Asymmetric even-harmonic generation (BJT reverse-saturation)
// 2. A/B comparison between MS20Diode (pure odd harmonics) and MS20Circuit (even + odd)
// 3. Autonomous limit-cycle self-oscillation
// 4. Authentic MS-20 Dual Serial Patch (HPF -> LPF)
// =====================================================================

s.waitForBoot({
    // 1. A/B Comparison: Diode (Symmetric) vs Circuit (Asymmetric BJT)
    SynthDef(\compare_diode_vs_circuit, { |out = 0, model = 0, drive = 3.0, amp = 0.2|
        // Pure sine wave to highlight harmonic generation
        var src = SinOsc.ar(200) * 1.5;
        var sig = Select.ar(model, [
            // Model 0: MS20Diode (symmetric forward diodes -> 3f, 5f, 7f)
            MS20Diode.ar(src, 3000, 0.2, drive, 0),
            // Model 1: MS20Circuit (asymmetric reverse-saturation BJTs -> 2f, 3f, 4f, 5f)
            MS20Circuit.ar(src, 3000, 0.2, drive, 0)
        ]);
        Out.ar(out, (sig * amp) ! 2);
    }).add;

    // 2. Authentic Serial Dual MS-20 Bass Patch
    SynthDef(\circuit_serial_bass, { |out = 0, hpFreq = 160, lpFreq = 1800, res = 0.5, drive = 2.0, amp = 0.25|
        var osc1 = Saw.ar(55);
        var osc2 = Saw.ar(55.25);
        var sub  = Pulse.ar(27.5, 0.5) * 0.4;
        var src  = (osc1 + osc2 + sub) * 0.4;

        // Stage 1: Authentic MS-20 HPF (mode = 1)
        var hp = MS20Circuit.ar(src, hpFreq, 0.35, drive, 1);
        // Stage 2: Authentic MS-20 LPF (mode = 0)
        var lp = MS20Circuit.ar(hp, lpFreq, res, drive, 0);

        Out.ar(out, (lp * amp) ! 2);
    }).add;

    s.sync;

    Routine({
        ("--- 1. Auditioning MS20Diode (Symmetric, pure odd harmonics) ---").postln;
        x = Synth(\compare_diode_vs_circuit, [\model, 0, \drive, 3.0]);
        4.0.wait;
        x.free;

        ("--- 2. Auditioning MS20Circuit (Asymmetric BJT, prominent 2nd harmonic bite) ---").postln;
        x = Synth(\compare_diode_vs_circuit, [\model, 1, \drive, 3.0]);
        4.0.wait;
        x.free;

        ("--- 3. Auditioning MS20Circuit Serial Dual Filter Bass Patch ---").postln;
        x = Synth(\circuit_serial_bass, [\hpFreq, 180, \lpFreq, 2000, \res, 0.65, \drive, 2.5]);
        5.0.wait;
        x.free;

        ("MS20Circuit Demonstration Complete!").postln;
    }).play;
});
