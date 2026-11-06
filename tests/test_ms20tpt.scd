// MS20TPT Milestone 2 Verification Script

s = Server.default;
s.options.numOutputBusChannels = 2;
s.options.numInputBusChannels = 2;

s.waitForBoot {
    var numErrors = 0;
    var sr = s.sampleRate;
    ("SuperCollider Server booted at sample rate: " ++ sr).postln;

    // 1. Verify Class and SynthDef graph compilation
    ("--- Test 1: Class and SynthDef graph compilation ---").postln;
    try {
        var def = SynthDef(\testMS20TPT_Compilation, {
            var in = WhiteNoise.ar(0.1);
            var lp = MS20TPT.ar(in, 1000, 0.25, 0);
            var hp = MS20TPT.ar(lp, 200, 0.25, 1);
            Out.ar(0, hp);
        });
        ("PASS: SynthDef using MS20TPT compiled successfully.").postln;
    } { |err|
        ("FAIL: SynthDef compilation failed: " ++ err).postln;
        numErrors = numErrors + 1;
    };

    // 2. Direct A/B Static Equivalence with MS20SK (Null Test)
    ("--- Test 2: Static Equivalence Null-Test (MS20SK vs MS20TPT) ---").postln;
    fork {
        var diffBus = Bus.control(s, 1);
        var nullSynth, maxDiff = 0.0, sem = Semaphore(0);

        nullSynth = {
            var src = Saw.ar(220) * 0.2 + PinkNoise.ar(0.05);
            // Identical static parameters
            var skOut  = MS20SK.ar(src, 1200, 0.65, 0);
            var tptOut = MS20TPT.ar(src, 1200, 0.65, 0);
            var diff = (skOut - tptOut).abs;
            var maxDiffTracker = RunningMax.ar(diff, Impulse.kr(20));
            Out.kr(diffBus, A2K.kr(maxDiffTracker));
        }.play(s);

        0.2.wait;
        diffBus.get({ |val|
            maxDiff = val;
            sem.signal;
        });
        sem.wait;
        nullSynth.free;
        diffBus.free;

        ("Max Absolute Difference |MS20SK - MS20TPT|: " ++ maxDiff.asString).postln;
        if (maxDiff < 0.0001) {
            ("PASS: MS20TPT and MS20SK agree to high numerical precision in static linear operation.").postln;
        } {
            ("FAIL: Significant discrepancy between MS20SK and MS20TPT!").postln;
            numErrors = numErrors + 1;
        };

        // 3. Measure frequency response slopes for MS20TPT
        ("--- Test 3: Frequency Response & Slope Verification for MS20TPT ---").postln;
        {
            var measureGain = { |testFreq, filterFreq, filterRes, filterMode|
                var synth, respBus = Bus.control(s, 1);
                var rmsVal = 0.0;
                var sSem = Semaphore(0);

                synth = {
                    var sig = SinOsc.ar(testFreq, 0, 1.0);
                    var flt = MS20TPT.ar(sig, filterFreq, filterRes, filterMode);
                    var rms = RunningSum.ar(flt.squared, 2048).sqrt / sqrt(2048);
                    Out.kr(respBus, A2K.kr(rms));
                }.play(s);

                0.2.wait;
                respBus.get({ |val|
                    rmsVal = val;
                    sSem.signal;
                });
                sSem.wait;
                synth.free;
                respBus.free;
                rmsVal;
            };

            var g_lp_dc, g_lp_2000, g_lp_4000, lp_slope;
            var g_hp_100, g_hp_200, g_hp_nyq, hp_slope;
            var g_res_low, g_res_high, peak_gain_db;

            // --- Low-Pass Slope Test ---
            g_lp_dc   = measureGain.(50, 1000, 0.0, 0);
            g_lp_2000 = measureGain.(2000, 500, 0.0, 0);
            g_lp_4000 = measureGain.(4000, 500, 0.0, 0);
            lp_slope = 20 * ( (g_lp_4000 / g_lp_2000).log10 );

            ("TPT LP DC Passband Gain (50 Hz, fc=1000 Hz): " ++ g_lp_dc.round(0.001)).postln;
            ("TPT LP Stopband Gain at 2000 Hz: " ++ g_lp_2000.round(0.0001)).postln;
            ("TPT LP Stopband Gain at 4000 Hz: " ++ g_lp_4000.round(0.0001)).postln;
            ("TPT LP Measured Slope (2000 to 4000 Hz): " ++ lp_slope.round(0.1) ++ " dB/oct (expected ~ -12 dB/oct)").postln;

            if (lp_slope < -10.5 and: { lp_slope > -14.5 }) {
                ("PASS: MS20TPT LP exhibits expected ~12 dB/octave stopband slope.").postln;
            } {
                ("FAIL: MS20TPT LP slope out of expected range!").postln;
                numErrors = numErrors + 1;
            };

            // --- High-Pass Slope Test (Historical MS-20 6 dB/octave slope) ---
            g_hp_100  = measureGain.(100, 2000, 0.0, 1);
            g_hp_200  = measureGain.(200, 2000, 0.0, 1);
            g_hp_nyq  = measureGain.(10000, 2000, 0.0, 1);
            hp_slope = 20 * ( (g_hp_200 / g_hp_100).log10 );

            ("TPT HP Low-Frequency Gain at 100 Hz: " ++ g_hp_100.round(0.0001)).postln;
            ("TPT HP Low-Frequency Gain at 200 Hz: " ++ g_hp_200.round(0.0001)).postln;
            ("TPT HP Passband Gain at 10000 Hz: " ++ g_hp_nyq.round(0.001)).postln;
            ("TPT HP Measured Low-Frequency Slope (100 to 200 Hz): " ++ hp_slope.round(0.1) ++ " dB/oct (expected ~ +6 dB/oct)").postln;

            if (hp_slope > 5.0 and: { hp_slope < 7.0 }) {
                ("PASS: MS20TPT HP exhibits authentic MS-20 ~6 dB/octave slope.").postln;
            } {
                ("FAIL: MS20TPT HP slope out of expected range!").postln;
                numErrors = numErrors + 1;
            };

            // --- Resonance Peak Growth Test ---
            g_res_low  = measureGain.(1000, 1000, 0.0, 0);
            g_res_high = measureGain.(1000, 1000, 0.85, 0);
            peak_gain_db = 20 * ( (g_res_high / g_res_low).log10 );

            ("TPT Resonance Peak Growth (1000 Hz, res=0.0 vs res=0.85): +" ++ peak_gain_db.round(0.1) ++ " dB").postln;
            if (peak_gain_db > 8.0) {
                ("PASS: MS20TPT Resonance increases resonant peak gain cleanly.").postln;
            } {
                ("FAIL: MS20TPT Resonance peak did not grow as expected!").postln;
                numErrors = numErrors + 1;
            };
        }.value;

        // 4. Stability with Silence, DC Step, and Modulation Sweeps
        ("--- Test 4: Silence, DC, and Modulation Stability ---").postln;
        {
            var testSynth, outBus = Bus.control(s, 1);
            var isNan = 0.0;
            var semMod = Semaphore(0);

            testSynth = {
                var sig = Saw.ar(110) * 0.1;
                // Cutoff modulation sweep across spectrum
                var cutoffMod = XLine.kr(80, 12000, 0.1);
                var flt = MS20TPT.ar(sig, cutoffMod, 0.9, 0);
                var checkNan = CheckBadValues.ar(flt, post: 0);
                Out.kr(outBus, A2K.kr(checkNan));
            }.play(s);

            0.15.wait;
            outBus.get({ |val|
                isNan = val;
                semMod.signal;
            });
            semMod.wait;
            testSynth.free;
            outBus.free;

            if (isNan == 0) {
                ("PASS: MS20TPT operates cleanly without NaN/Inf during rapid cutoff modulation.").postln;
            } {
                ("FAIL: Bad values detected during modulation!").postln;
                numErrors = numErrors + 1;
            };
        }.value;

        // --- Summary & Exit ---
        0.1.wait;
        ("========================================").postln;
        if (numErrors == 0) {
            ("ALL MILESTONE 2 VERIFICATION TESTS PASSED!").postln;
            0.exit;
        } {
            ("FAILURE: " ++ numErrors ++ " tests failed!").postln;
            1.exit;
        };
    };
};
