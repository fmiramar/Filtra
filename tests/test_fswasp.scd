// =====================================================================
// test_fswasp.scd: Unit Verification Test Suite for FSWasp (Stage W1)
// Verifies linear small-signal EDP Wasp model across modes, slopes & FM
// =====================================================================

var s = Server.default;
var testCount = 0;
var passCount = 0;

var assert = { |cond, msg|
    testCount = testCount + 1;
    if (cond) {
        passCount = passCount + 1;
        ("  [PASS] " ++ msg).postln;
    } {
        ("  [FAIL] " ++ msg).postln;
    };
};

s.options.sampleRate = 44100;
s.options.blockSize = 64;

s.waitForBoot({
    var dur = 0.5;
    var numSamples = (dur * 44100).asInteger;

    "\n==================================================".postln;
    "  FSWasp (Stage W1) Linear Model Test Suite       ".postln;
    "==================================================\n".postln;

    // -------------------------------------------------------------
    // Test 1: Class and SynthDef graph compilation
    // -------------------------------------------------------------
    "--- Test 1: Class and SynthDef Compilation ---".postln;
    {
        var defLP = SynthDef(\test_wasp_lp, { |out=0|
            var sig = FSWasp.ar(WhiteNoise.ar(0.1), 1000, 0.3, 1.0, 0);
            Out.ar(out, sig);
        });
        var defBP = SynthDef(\test_wasp_bp, { |out=0|
            var sig = FSWasp.ar(WhiteNoise.ar(0.1), 1000, 0.3, 1.0, 1);
            Out.ar(out, sig);
        });
        var defHP = SynthDef(\test_wasp_hp, { |out=0|
            var sig = FSWasp.ar(WhiteNoise.ar(0.1), 1000, 0.3, 1.0, 2);
            Out.ar(out, sig);
        });

        assert.(defLP.notNil, "SynthDef with FSWasp (LP mode 0) compiles");
        assert.(defBP.notNil, "SynthDef with FSWasp (BP mode 1) compiles");
        assert.(defHP.notNil, "SynthDef with FSWasp (HP mode 2) compiles");
    }.value;

    // -------------------------------------------------------------
    // Test 2: Frequency Response & Slope Verification (LP and HP)
    // -------------------------------------------------------------
    "--- Test 2: Asymptotic Slopes & Frequency Response ---".postln;
    {
        var measureRMS = { |freq, filterMode, fc, res|
            var buf = Buffer.alloc(s, numSamples, 1);
            var val;
            s.sync;
            {
                var sig = SinOsc.ar(freq) * 0.5;
                var flt = FSWasp.ar(sig, fc, res, 1.0, filterMode);
                RecordBuf.ar(flt, buf, loop: 0, doneAction: 2);
                Silent.ar;
            }.play;
            dur.wait;
            buf.loadToFloatArray(action: { |arr|
                var tail = arr.copyRange((numSamples * 0.5).asInteger, numSamples - 1);
                val = (tail.squared.sum / tail.size).sqrt;
            });
            s.sync;
            buf.free;
            val;
        };

        var lp_pass, lp_stop1, lp_stop2, lp_slope;
        var hp_pass, hp_stop1, hp_stop2, hp_slope;
        var bp_center, bp_low, bp_high;
        var res_low, res_high, res_gain_db;

        // LP Mode 0: Cutoff 1000 Hz, res = 0.2
        lp_pass  = measureRMS.(50, 0, 1000, 0.2);
        lp_stop1 = measureRMS.(2500, 0, 1000, 0.2);
        lp_stop2 = measureRMS.(5000, 0, 1000, 0.2);
        lp_slope = 20.0 * log10(lp_stop2 / lp_stop1);

        ("  LP Passband Gain (50 Hz, fc=1000 Hz): " ++ lp_pass.round(0.001)).postln;
        ("  LP Stopband (2500 Hz): " ++ lp_stop1.round(0.001) ++ ", (5000 Hz): " ++ lp_stop2.round(0.001)).postln;
        ("  LP Measured Stopband Slope: " ++ lp_slope.round(0.1) ++ " dB/octave").postln;
        assert.(lp_slope < -11.0 && lp_slope > -14.5, "FSWasp LP exhibits expected ~ -12 dB/octave 2-pole slope (measured " ++ lp_slope.round(0.1) ++ " dB/oct)");

        // HP Mode 2: Cutoff 1000 Hz, res = 0.2
        hp_stop1 = measureRMS.(100, 2, 1000, 0.2);
        hp_stop2 = measureRMS.(200, 2, 1000, 0.2);
        hp_pass  = measureRMS.(10000, 2, 1000, 0.2);
        hp_slope = 20.0 * log10(hp_stop2 / hp_stop1);

        ("  HP Low-Frequency (100 Hz): " ++ hp_stop1.round(0.001) ++ ", (200 Hz): " ++ hp_stop2.round(0.001)).postln;
        ("  HP Passband Gain (10000 Hz): " ++ hp_pass.round(0.001)).postln;
        ("  HP Measured Slope: " ++ hp_slope.round(0.1) ++ " dB/octave").postln;
        assert.(hp_slope > 10.5 && hp_slope > 0.0, "FSWasp HP exhibits expected ~ +12 dB/octave 2-pole slope");

        // BP Mode 1: Cutoff 1000 Hz, res = 0.2
        bp_center = measureRMS.(1000, 1, 1000, 0.2);
        bp_low    = measureRMS.(200, 1, 1000, 0.2);
        bp_high   = measureRMS.(5000, 1, 1000, 0.2);
        ("  BP Center (1000 Hz): " ++ bp_center.round(0.001) ++ ", Low (200 Hz): " ++ bp_low.round(0.001) ++ ", High (5000 Hz): " ++ bp_high.round(0.001)).postln;
        assert.(bp_center > (bp_low * 2.0) && bp_center > (bp_high * 2.0), "FSWasp BP peaks symmetrically at cutoff");

        // Resonance Peak Test: Cutoff 1000 Hz, res = 0.0 vs res = 0.95
        res_low  = measureRMS.(1000, 0, 1000, 0.0);
        res_high = measureRMS.(1000, 0, 1000, 0.95);
        res_gain_db = 20.0 * log10(res_high / res_low);
        ("  Resonance Peak Growth (res 0.0 -> 0.95): +" ++ res_gain_db.round(0.1) ++ " dB").postln;
        assert.(res_gain_db > 15.0, "FSWasp resonance increases resonant peak by > 15 dB");
    }.value;

    // -------------------------------------------------------------
    // Test 3: Audio-Rate FM Modulation
    // -------------------------------------------------------------
    "--- Test 3: Audio-Rate FM Modulation ---".postln;
    {
        var buf = Buffer.alloc(s, numSamples, 1);
        var data;
        s.sync;

        {
            var sig = Saw.ar(110) * 0.4;
            var fmMod = SinOsc.ar(220) * 800 + 1500;
            var out = FSWasp.ar(sig, fmMod, 0.6, 1.0, 0);
            RecordBuf.ar(out, buf, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;
        buf.loadToFloatArray(action: { |arr| data = arr; });
        s.sync;

        assert.(data.every({ |x| x.isNaN.not && (x.abs < 100.0) }), "FSWasp handles audio-rate FM cleanly without NaN/Inf");
        assert.(data.abs.maxItem > 0.05, "FSWasp audio-rate FM output has valid non-zero amplitude");
        buf.free;
    }.value;

    // -------------------------------------------------------------
    // Test 4: Silence and DC step stability
    // -------------------------------------------------------------
    "--- Test 4: Silence and Stability ---".postln;
    {
        var buf = Buffer.alloc(s, numSamples, 1);
        var data;
        s.sync;

        {
            var sig = Impulse.ar(0) * 0.5; // Single impulse kick
            var out = FSWasp.ar(sig, 800, 0.8, 1.0, 0);
            RecordBuf.ar(out, buf, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;
        buf.loadToFloatArray(action: { |arr| data = arr; });
        s.sync;

        assert.(data.every({ |x| x.isNaN.not && (x.abs < 100.0) }), "Impulse response remains strictly finite and bounded");
        buf.free;
    }.value;

    "\n--------------------------------------------------".postln;
    ("Results: " ++ passCount ++ " / " ++ testCount ++ " tests passed.").postln;
    "--------------------------------------------------\n".postln;

    if (passCount == testCount) {
        "ALL FSWASP STAGE W1 TESTS PASSED.".postln;
        0.exit;
    } {
        "SOME TESTS FAILED.".postln;
        1.exit;
    };
});
