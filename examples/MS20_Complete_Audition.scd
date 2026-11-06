// =====================================================================
// MS20_Complete_Audition.scd: Master Audition Suite for the MS-20 Family
// Demonstrates all five models:
// 1. MS20SK      - Linear Sallen-Key Korg-35 Biquad Reference
// 2. MS20TPT     - Zero-Delay Topology-Preserving Transform (TPT/ZDF)
// 3. MS20Diode   - Early Korg-35 with Forward Amplifier Diode Limiter
// 4. MS20OTA     - Later KLM-307 Dual OTA Filter with Feedback Diodes
// 5. MS20Circuit - Component-Level BJT Reverse-Saturation MNA Circuit Model
// =====================================================================

s.waitForBoot({

    // -------------------------------------------------------------
    // PART 1: Model Comparison (Low Resonance, Clean Sweeps)
    // -------------------------------------------------------------
    SynthDef(\ms20_compare, { |out = 0, model = 0, mode = 0, gate = 1, amp = 0.2|
        var src = Saw.ar([110, 110.5]);
        var cutoffSweep = XLine.kr(8000, 150, 4);
        var res = 0.35;
        var sig;

        sig = Select.ar(model, [
            MS20SK.ar(src, cutoffSweep, res, mode),
            MS20TPT.ar(src, cutoffSweep, res, mode),
            MS20Diode.ar(src, cutoffSweep, res, 1.0, mode),
            MS20OTA.ar(src, cutoffSweep, res, 1.0, mode),
            MS20Circuit.ar(src, cutoffSweep, res, 1.0, mode)
        ]);

        sig = sig * EnvGen.kr(Env.asr(0.05, 1.0, 0.1), gate, doneAction: 2);
        Out.ar(out, sig * amp);
    }).add;

    // -------------------------------------------------------------
    // PART 2: High Resonance & Limit-Cycle Self-Oscillation
    // Compares MS20Diode, MS20OTA, and MS20Circuit.
    // -------------------------------------------------------------
    SynthDef(\ms20_self_osc, { |out = 0, model = 2, drive = 2.0, amp = 0.2|
        var src = Impulse.ar(0) * 0.01;
        var cutoff = SinOsc.kr(0.2).exprange(300, 2500);
        var sig;

        sig = Select.ar(model - 2, [
            // MS20Diode: Korg-35 forward diodes limit total amplitude
            MS20Diode.ar(src, cutoff, 0.95, drive, 0),
            // MS20OTA: KLM-307 feedback diodes limit only the resonance peak
            MS20OTA.ar(src, cutoff, 0.95, drive, 0),
            // MS20Circuit: BJT reverse-saturation + forward diodes
            MS20Circuit.ar(src, cutoff, 0.90, drive, 0)
        ]);

        Out.ar(out, (sig * amp) ! 2);
    }).add;

    // -------------------------------------------------------------
    // PART 3: Audio-Rate Frequency Modulation (Sample-Accurate FM)
    // -------------------------------------------------------------
    SynthDef(\ms20_audio_fm, { |out = 0, model = 4, fmfreq = 220, fmdepth = 2000, amp = 0.15|
        var carrier = Saw.ar(55);
        var mod = SinOsc.ar(fmfreq) * fmdepth;
        var cutoff = (mod + 2500).clip(20, 18000);
        var sig;

        sig = Select.ar(model, [
            MS20SK.ar(carrier, cutoff, 0.5, 0),
            MS20TPT.ar(carrier, cutoff, 0.5, 0),
            MS20Diode.ar(carrier, cutoff, 0.5, 2.0, 0),
            MS20OTA.ar(carrier, cutoff, 0.5, 2.0, 0),
            MS20Circuit.ar(carrier, cutoff, 0.5, 2.0, 0)
        ]);

        Out.ar(out, (sig * amp) ! 2);
    }).add;

    // -------------------------------------------------------------
    // PART 4: Authentic Serial MS-20 Dual-Filter Patch (HPF -> LPF)
    // -------------------------------------------------------------
    SynthDef(\ms20_serial_dual, { |out = 0, hpFreq = 200, hpRes = 0.5, lpFreq = 1500, lpRes = 0.6, drive = 2.0, amp = 0.2|
        var osc1 = Saw.ar(55);
        var osc2 = Saw.ar(55.3);
        var sub  = Pulse.ar(27.5, 0.5) * 0.5;
        var src  = (osc1 + osc2 + sub) * 0.4;

        // Stage 1: Authentic MS-20 High-Pass Filter (mode = 1)
        var hp = MS20Circuit.ar(src, hpFreq, hpRes, drive, 1);

        // Stage 2: Authentic MS-20 Low-Pass Filter (mode = 0)
        var lp = MS20Circuit.ar(hp, lpFreq, lpRes, drive, 0);

        Out.ar(out, (lp * amp) ! 2);
    }).add;

    s.sync;

    // -------------------------------------------------------------
    // Audition Sequence
    // -------------------------------------------------------------
    Routine({
        ("======================================================").postln;
        ("MS-20 Filter Family Audition Suite Starting...").postln;
        ("======================================================").postln;

        // 1. Audition linear references
        ("1. Auditioning Linear Sallen-Key (MS20SK)...").postln;
        x = Synth(\ms20_compare, [\model, 0, \mode, 0]);
        4.0.wait;

        ("2. Auditioning Zero-Delay TPT Model (MS20TPT)...").postln;
        x = Synth(\ms20_compare, [\model, 1, \mode, 0]);
        4.0.wait;

        // 2. Audition nonlinear models
        ("3. Auditioning Early Korg-35 Diode Model (MS20Diode)...").postln;
        x = Synth(\ms20_compare, [\model, 2, \mode, 0]);
        4.0.wait;

        ("4. Auditioning Later KLM-307 Dual OTA Model (MS20OTA)...").postln;
        x = Synth(\ms20_compare, [\model, 3, \mode, 0]);
        4.0.wait;

        ("5. Auditioning Discrete BJT Circuit Model (MS20Circuit)...").postln;
        x = Synth(\ms20_compare, [\model, 4, \mode, 0]);
        4.0.wait;

        // 3. Resonant Self-Oscillation
        ("6. Auditioning Discrete BJT Limit Cycle (MS20Circuit)...").postln;
        x = Synth(\ms20_self_osc, [\model, 4, \drive, 2.0]);
        4.0.wait;
        x.free;

        // 4. Audio-Rate Filter FM
        ("7. Auditioning Audio-Rate FM (MS20Circuit, 220 Hz FM Modulator)...").postln;
        x = Synth(\ms20_audio_fm, [\model, 4, \fmfreq, 220, \fmdepth, 2000]);
        4.0.wait;
        x.free;

        // 5. Authentic Serial Dual Filter Patch
        ("8. Auditioning Authentic Dual Serial MS-20 Patch with MS20Circuit (HPF -> LPF)...").postln;
        x = Synth(\ms20_serial_dual, [
            \hpFreq, 180,  \hpRes, 0.45,
            \lpFreq, 2200, \lpRes, 0.65,
            \drive, 2.0
        ]);
        5.0.wait;
        x.free;

        ("======================================================").postln;
        ("MS-20 Audition Sequence Complete!").postln;
        ("======================================================").postln;
    }).play;
});
