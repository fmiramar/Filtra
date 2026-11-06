// MS20OTA Milestone 4 Verification Script

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
        var def = SynthDef(\testMS20OTA_Compilation, {
            var in = WhiteNoise.ar(0.1);
            var lp = MS20OTA.ar(in, 1000, 0.25, 1.0, 0);
            var hp = MS20OTA.ar(lp, 200, 0.25, 1.0, 1);
            Out.ar(0, hp);
        });
        ("PASS: SynthDef using MS20OTA compiled successfully.").postln;
    } { |err|
        ("FAIL: SynthDef compilation failed: " ++ err).postln;
        numErrors = numErrors + 1;
    };

    fork {
        // 2. Frequency response slopes
        ("--- Test 2: Frequency Response & Slope Verification for MS20OTA ---").postln;
        {
            var measureGain = { |testFreq, filterFreq, filterRes, filterMode|
                var synth, respBus = Bus.control(s, 1);
                var rmsVal = 0.0;
                var sSem = Semaphore(0);

                synth = {
                    var sig = SinOsc.ar(testFreq, 0, 1.0);
                    var flt = MS20OTA.ar(sig, filterFreq, filterRes, 1.0, filterMode);
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

            // --- Low-Pass Slope Test ---
            g_lp_dc   = measureGain.(50, 1000, 0.0, 0);
            g_lp_2000 = measureGain.(2000, 500, 0.0, 0);
            g_lp_4000 = measureGain.(4000, 500, 0.0, 0);
            lp_slope = 20 * ( (g_lp_4000 / g_lp_2000).log10 );

            ("OTA LP DC Passband Gain (50 Hz, fc=1000 Hz): " ++ g_lp_dc.round(0.001)).postln;
            ("OTA LP Stopband Gain at 2000 Hz: " ++ g_lp_2000.round(0.0001)).postln;
            ("OTA LP Stopband Gain at 4000 Hz: " ++ g_lp_4000.round(0.0001)).postln;
            ("OTA LP Measured Slope (2000 to 4000 Hz): " ++ lp_slope.round(0.1) ++ " dB/oct (expected ~ -12 dB/oct)").postln;

            if (lp_slope < -11.0 and: { lp_slope > -13.0 }) {
                ("PASS: MS20OTA LP exhibits expected ~12 dB/octave stopband slope.").postln;
            } {
                ("FAIL: MS20OTA LP slope out of expected range!").postln;
                numErrors = numErrors + 1;
            };

            // --- High-Pass Slope Test (Historical MS-20 6 dB/octave slope) ---
            g_hp_100  = measureGain.(100, 2000, 0.0, 1);
            g_hp_200  = measureGain.(200, 2000, 0.0, 1);
            g_hp_nyq  = measureGain.(10000, 2000, 0.0, 1);
            hp_slope = 20 * ( (g_hp_200 / g_hp_100).log10 );

            ("OTA HP Low-Frequency Gain at 100 Hz: " ++ g_hp_100.round(0.0001)).postln;
            ("OTA HP Low-Frequency Gain at 200 Hz: " ++ g_hp_200.round(0.0001)).postln;
            ("OTA HP Passband Gain at 10000 Hz: " ++ g_hp_nyq.round(0.001)).postln;
            ("OTA HP Measured Low-Frequency Slope (100 to 200 Hz): " ++ hp_slope.round(0.1) ++ " dB/oct (expected ~ +6 dB/oct)").postln;

            if (hp_slope > 5.0 and: { hp_slope < 7.0 }) {
                ("PASS: MS20OTA HP exhibits authentic MS-20 ~6 dB/octave slope.").postln;
            } {
                ("FAIL: MS20OTA HP slope out of expected range!").postln;
                numErrors = numErrors + 1;
            };
        }.value;

        // 3. Clean Passband Verification (Feedback Diodes do not distort passband)
        ("--- Test 3: Clean Passband vs Resonant Peaking Saturation ---").postln;
        {
            var diffBus = Bus.control(s, 1);
            var synth, maxDiff = 0.0, sSem = Semaphore(0);

            synth = {
                // Passband tone (150 Hz with fc=3000 Hz)
                var src = SinOsc.ar(150, 0, 1.0);
                // Compare low drive (1.0) vs high drive (3.0) on passband signal
                var sigLow  = MS20OTA.ar(src, 3000, 0.2, 1.0, 0);
                var sigHigh = MS20OTA.ar(src, 3000, 0.2, 3.0, 0);
                var diff = (sigHigh - sigLow).abs;
                Out.kr(diffBus, A2K.kr(RunningMax.ar(diff, Impulse.kr(20))));
            }.play(s);

            0.2.wait;
            diffBus.get({ |val|
                maxDiff = val;
                sSem.signal;
            });
            sSem.wait;
            synth.free;
            diffBus.free;

            ("OTA Passband Deviation between Drive=1.0 and Drive=3.0: " ++ maxDiff.asString).postln;
            if (maxDiff < 0.001) {
                ("PASS: MS20OTA preserves clean passband immunity (< 0.1% change across 3x drive).").postln;
            } {
                ("FAIL: Unexpected passband distortion under drive!").postln;
                numErrors = numErrors + 1;
            };
        }.value;

        // 4. Autonomous Limit-Cycle Self-Oscillation
        ("--- Test 4: Autonomous Limit-Cycle Self-Oscillation ---").postln;
        {
            var oscBus = Bus.control(s, 1);
            var synth, oscRms = 0.0, sSem = Semaphore(0);

            synth = {
                var trigger = Impulse.ar(0) * 0.01;
                var selfOsc = MS20OTA.ar(trigger, freq: 800, res: 0.95, drive: 1.0, mode: 0);
                var rms = RunningSum.ar(selfOsc.squared, 4096).sqrt / sqrt(4096);
                Out.kr(oscBus, A2K.kr(rms));
            }.play(s);

            0.35.wait;
            oscBus.get({ |val|
                oscRms = val;
                sSem.signal;
            });
            sSem.wait;
            synth.free;
            oscBus.free;

            ("OTA Self-Oscillation Limit-Cycle RMS: " ++ oscRms.round(0.001)).postln;
            if (oscRms > 0.3 and: { oscRms < 0.9 }) {
                ("PASS: MS20OTA self-oscillates stably into a bounded limit cycle.").postln;
            } {
                ("FAIL: Self-oscillation level outside expected range!").postln;
                numErrors = numErrors + 1;
            };
        }.value;

        // 5. Silence, DC, and Modulation Stability
        ("--- Test 5: Silence, DC, and Modulation Stability ---").postln;
        {
            var testSynth, outBus = Bus.control(s, 1);
            var isNan = 0.0;
            var semMod = Semaphore(0);

            testSynth = {
                var sig = Saw.ar(110) * 0.5;
                var cutoffMod = XLine.kr(50, 15000, 0.1);
                var flt = MS20OTA.ar(sig, cutoffMod, 0.95, 2.0, 0);
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
                ("PASS: MS20OTA operates cleanly without NaN/Inf during aggressive modulation.").postln;
            } {
                ("FAIL: Bad values detected during modulation!").postln;
                numErrors = numErrors + 1;
            };
        }.value;

        // --- Summary & Exit ---
        0.1.wait;
        ("========================================").postln;
        if (numErrors == 0) {
            ("ALL MILESTONE 4 VERIFICATION TESTS PASSED!").postln;
            0.exit;
        } {
            ("FAILURE: " ++ numErrors ++ " tests failed!").postln;
            1.exit;
        };
    };
};
