// MS20SK Milestone 1 Verification Script

s = Server.default;
s.options.numOutputBusChannels = 2;
s.options.numInputBusChannels = 2;

s.waitForBoot {
    var numErrors = 0;
    var sr = s.sampleRate;
    ("SuperCollider Server booted at sample rate: " ++ sr).postln;

    // 1. Verify Class and UGen Graph compilation
    ("--- Test 1: Class and SynthDef graph compilation ---").postln;
    try {
        var def = SynthDef(\testMS20SK_Compilation, {
            var in = WhiteNoise.ar(0.1);
            var lp = MS20SK.ar(in, 1000, 0.25, 0);
            var hp = MS20SK.ar(lp, 200, 0.25, 1);
            Out.ar(0, hp);
        });
        ("PASS: SynthDef using MS20SK compiled successfully.").postln;
    } { |err|
        ("FAIL: SynthDef compilation failed: " ++ err).postln;
        numErrors = numErrors + 1;
    };

    // 2. Measure frequency response slopes
    ("--- Test 2: Frequency Response & Slope Verification ---").postln;

    fork {
        var measureGain = { |testFreq, filterFreq, filterRes, filterMode|
            var synth, respBus = Bus.control(s, 1);
            var rmsVal = 0.0;
            var sem = Semaphore(0);

            synth = {
                var sig = SinOsc.ar(testFreq, 0, 1.0);
                var flt = MS20SK.ar(sig, filterFreq, filterRes, filterMode);
                var rms = RunningSum.ar(flt.squared, 2048).sqrt / sqrt(2048);
                Out.kr(respBus, A2K.kr(rms));
            }.play(s);

            0.2.wait; // Let transient settle
            respBus.get({ |val|
                rmsVal = val;
                sem.signal;
            });
            sem.wait;
            synth.free;
            respBus.free;
            rmsVal;
        };

        var g_lp_dc, g_lp_2000, g_lp_4000, lp_slope;
        var g_hp_100, g_hp_200, g_hp_nyq, hp_slope;
        var g_res_low, g_res_high, peak_gain_db;
        var testSynth, outBus, isNan, sem;

        // --- Low-Pass Slope Test ---
        g_lp_dc   = measureGain.(50, 1000, 0.0, 0);
        g_lp_2000 = measureGain.(2000, 500, 0.0, 0);
        g_lp_4000 = measureGain.(4000, 500, 0.0, 0);
        lp_slope = 20 * ( (g_lp_4000 / g_lp_2000).log10 );

        ("LP DC Passband Gain (50 Hz, fc=1000 Hz): " ++ g_lp_dc.round(0.001) ++ " (expected ~0.707 for sine RMS)").postln;
        ("LP Stopband Gain at 2000 Hz: " ++ g_lp_2000.round(0.0001)).postln;
        ("LP Stopband Gain at 4000 Hz: " ++ g_lp_4000.round(0.0001)).postln;
        ("LP Measured Slope (2000 to 4000 Hz): " ++ lp_slope.round(0.1) ++ " dB/oct (expected ~ -12 dB/oct)").postln;

        if (lp_slope < -10.5 and: { lp_slope > -14.5 }) {
            ("PASS: LP filter exhibits expected ~12 dB/octave stopband slope.").postln;
        } {
            ("FAIL: LP slope out of expected range!").postln;
            numErrors = numErrors + 1;
        };

        // --- High-Pass Slope Test (Historical MS-20 6 dB/octave slope) ---
        g_hp_100  = measureGain.(100, 2000, 0.0, 1);
        g_hp_200  = measureGain.(200, 2000, 0.0, 1);
        g_hp_nyq  = measureGain.(10000, 2000, 0.0, 1);
        hp_slope = 20 * ( (g_hp_200 / g_hp_100).log10 );

        ("HP Low-Frequency Gain at 100 Hz: " ++ g_hp_100.round(0.0001)).postln;
        ("HP Low-Frequency Gain at 200 Hz: " ++ g_hp_200.round(0.0001)).postln;
        ("HP Passband Gain at 10000 Hz: " ++ g_hp_nyq.round(0.001) ++ " (expected ~0.707 for sine RMS)").postln;
        ("HP Measured Low-Frequency Slope (100 to 200 Hz): " ++ hp_slope.round(0.1) ++ " dB/oct (expected ~ +6 dB/oct)").postln;

        if (hp_slope > 5.0 and: { hp_slope < 7.0 }) {
            ("PASS: HP filter exhibits authentic MS-20 ~6 dB/octave slope.").postln;
        } {
            ("FAIL: HP slope out of expected range!").postln;
            numErrors = numErrors + 1;
        };

        // --- Resonance Peak Growth Test ---
        g_res_low  = measureGain.(1000, 1000, 0.0, 0);
        g_res_high = measureGain.(1000, 1000, 0.85, 0);
        peak_gain_db = 20 * ( (g_res_high / g_res_low).log10 );

        ("Resonance Peak Growth (1000 Hz, res=0.0 vs res=0.85): +" ++ peak_gain_db.round(0.1) ++ " dB").postln;
        if (peak_gain_db > 8.0) {
            ("PASS: Resonance increases resonant peak gain cleanly.").postln;
        } {
            ("FAIL: Resonance peak did not grow as expected!").postln;
            numErrors = numErrors + 1;
        };

        // --- Stability with DC and Silence ---
        ("--- Test 3: Silence and DC stability ---").postln;
        outBus = Bus.control(s, 1);
        isNan = 0.0;
        sem = Semaphore(0);

        testSynth = {
            var sig = Line.ar(0, 1, 0.01) * Line.ar(1, 0, 0.05);
            var flt = MS20SK.ar(sig, 100, 0.95, 0);
            var checkNan = CheckBadValues.ar(flt, post: 0);
            Out.kr(outBus, A2K.kr(checkNan));
        }.play(s);

        0.1.wait;
        outBus.get({ |val|
            isNan = val;
            sem.signal;
        });
        sem.wait;
        testSynth.free;
        outBus.free;

        if (isNan == 0) {
            ("PASS: Filter handles DC step and silence without NaN/Inf.").postln;
        } {
            ("FAIL: Bad values detected in filter output!").postln;
            numErrors = numErrors + 1;
        };

        // --- Summary & Exit ---
        0.1.wait;
        ("========================================").postln;
        if (numErrors == 0) {
            ("ALL MILESTONE 1 VERIFICATION TESTS PASSED!").postln;
            0.exit;
        } {
            ("FAILURE: " ++ numErrors ++ " tests failed!").postln;
            1.exit;
        };
    };
};
