// =====================================================================
// test_fssteiner.scd: Unit Verification Test Suite for FSSteiner
// Verifies Steiner-Parker diode multimode VCF across LP/BP/HP,
// small-signal convergence, audio FM, and nonlinear diode limit cycle.
// Reference: Nyle Steiner (1974), Yves Usson (YuSynth 2004)
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
    "  FSSteiner Diode Multimode VCF Verification Suite".postln;
    "==================================================\n".postln;

    // -------------------------------------------------------------
    // Test 1: Class and SynthDef graph compilation
    // -------------------------------------------------------------
    "--- Test 1: Class and SynthDef Compilation ---".postln;
    {
        var defLP = SynthDef(\test_steiner_lp, { |out=0|
            var sig = FSSteiner.ar(WhiteNoise.ar(0.1), 1000, 0.3, 0, 1.0);
            Out.ar(out, sig);
        });
        var defBP = SynthDef(\test_steiner_bp, { |out=0|
            var sig = FSSteiner.ar(WhiteNoise.ar(0.1), 1000, 0.3, 1, 1.0);
            Out.ar(out, sig);
        });
        var defHP = SynthDef(\test_steiner_hp, { |out=0|
            var sig = FSSteiner.ar(WhiteNoise.ar(0.1), 1000, 0.3, 2, 1.0);
            Out.ar(out, sig);
        });

        assert.(defLP.notNil, "SynthDef with FSSteiner (LP mode 0) compiles");
        assert.(defBP.notNil, "SynthDef with FSSteiner (BP mode 1) compiles");
        assert.(defHP.notNil, "SynthDef with FSSteiner (HP mode 2) compiles");
    }.value;

    // -------------------------------------------------------------
    // Test 2: Frequency Response & Slope Verification (LP, BP, HP)
    // -------------------------------------------------------------
    "--- Test 2: Asymptotic Slopes & Frequency Response ---".postln;
    {
        var measureRMS = { |freq, filterMode, fc, res, drive=0.0|
            var buf = Buffer.alloc(s, numSamples, 1);
            var val;
            s.sync;
            {
                var sig = SinOsc.ar(freq) * 0.1;
                var flt = FSSteiner.ar(sig, fc, res, filterMode, drive);
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
        assert.(lp_slope < -10.0 && lp_slope > -14.5, "FSSteiner LP exhibits expected ~ -12 dB/octave 2-pole slope (measured " ++ lp_slope.round(0.1) ++ " dB/oct)");

        // HP Mode 2: Cutoff 1000 Hz, res = 0.2
        hp_stop1 = measureRMS.(100, 2, 1000, 0.2);
        hp_stop2 = measureRMS.(200, 2, 1000, 0.2);
        hp_pass  = measureRMS.(10000, 2, 1000, 0.2);
        hp_slope = 20.0 * log10(hp_stop2 / hp_stop1);

        ("  HP Low-Frequency (100 Hz): " ++ hp_stop1.round(0.001) ++ ", (200 Hz): " ++ hp_stop2.round(0.001)).postln;
        ("  HP Passband Gain (10000 Hz): " ++ hp_pass.round(0.001)).postln;
        ("  HP Measured Slope: " ++ hp_slope.round(0.1) ++ " dB/octave").postln;
        assert.(hp_slope > 4.5 && hp_slope > 0.0, "FSSteiner HP exhibits expected ~ +6 dB/octave slope (measured " ++ hp_slope.round(0.1) ++ " dB/oct)");

        // BP Mode 1: Cutoff 1000 Hz, res = 0.2
        bp_center = measureRMS.(1000, 1, 1000, 0.2);
        bp_low    = measureRMS.(200, 1, 1000, 0.2);
        bp_high   = measureRMS.(5000, 1, 1000, 0.2);
        ("  BP Center (1000 Hz): " ++ bp_center.round(0.001) ++ ", Low (200 Hz): " ++ bp_low.round(0.001) ++ ", High (5000 Hz): " ++ bp_high.round(0.001)).postln;
        assert.(bp_center > (bp_low * 2.0) && bp_center > (bp_high * 1.5), "FSSteiner BP peaks symmetrically at cutoff");

        // Resonance Peak Test: Cutoff 1000 Hz, res = 0.0 vs res = 0.75 (linear small-signal)
        res_low  = measureRMS.(1000, 0, 1000, 0.0, 0.0);
        res_high = measureRMS.(1000, 0, 1000, 0.75, 0.0);
        res_gain_db = 20.0 * log10(res_high / res_low);
        ("  Linear Resonance Peak Growth (res 0.0 -> 0.75): +" ++ res_gain_db.round(0.1) ++ " dB").postln;
        assert.(res_gain_db > 12.0, "FSSteiner resonance increases resonant peak by > 12 dB (measured " ++ res_gain_db.round(0.1) ++ " dB)");
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
            var out = FSSteiner.ar(sig, fmMod, 0.6, 0, 1.5);
            RecordBuf.ar(out, buf, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;
        buf.loadToFloatArray(action: { |arr| data = arr; });
        s.sync;

        assert.(data.every({ |x| x.isNaN.not && (x.abs < 100.0) }), "FSSteiner handles audio-rate FM cleanly without NaN/Inf");
        assert.(data.abs.maxItem > 0.05, "FSSteiner audio-rate FM output has valid non-zero amplitude");
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
            var out = FSSteiner.ar(sig, 800, 0.5, 0, 1.0);
            RecordBuf.ar(out, buf, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;
        buf.loadToFloatArray(action: { |arr| data = arr; });
        s.sync;

        assert.(data.every({ |x| x.isNaN.not && (x.abs < 100.0) }), "Impulse response remains strictly finite and bounded");
        buf.free;
    }.value;

    // -------------------------------------------------------------
    // Test 5: Small-Signal Linear vs Nonlinear Convergence
    // -------------------------------------------------------------
    "--- Test 5: Small-Signal Linear vs Nonlinear Convergence ---".postln;
    {
        var bufLin = Buffer.alloc(s, numSamples, 1);
        var bufNL  = Buffer.alloc(s, numSamples, 1);
        var arrLin, arrNL, maxDiff;
        s.sync;

        // Quiet signal (amplitude 0.005)
        {
            var sig = SinOsc.ar(440) * 0.005;
            // drive=0.0 runs pure linear small-signal branch
            var out = FSSteiner.ar(sig, 1000, 0.4, 0, 0.0);
            RecordBuf.ar(out, bufLin, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;

        {
            var sig = SinOsc.ar(440) * 0.005;
            // drive=1.0 runs nonlinear diode Newton solver
            var out = FSSteiner.ar(sig, 1000, 0.4, 0, 1.0);
            RecordBuf.ar(out, bufNL, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;

        bufLin.loadToFloatArray(action: { |arr| arrLin = arr; });
        bufNL.loadToFloatArray(action: { |arr| arrNL = arr; });
        s.sync;

        maxDiff = (arrLin - arrNL).abs.maxItem;
        ("  Small-signal peak difference between linear and nonlinear model: " ++ maxDiff.asString).postln;
        assert.(maxDiff < 1e-4, "Nonlinear diode model converges to linear model at small signal levels (< 1e-4)");

        bufLin.free;
        bufNL.free;
    }.value;

    // -------------------------------------------------------------
    // Test 6: Nonlinear Diode Saturation & Crest Factor Compression
    // -------------------------------------------------------------
    "--- Test 6: Nonlinear Diode Saturation & Compression ---".postln;
    {
        var bufLow = Buffer.alloc(s, numSamples, 1);
        var bufHigh = Buffer.alloc(s, numSamples, 1);
        var arrLow, arrHigh;
        var rmsLow, rmsHigh, crestLow, crestHigh;
        s.sync;

        // Drive = 1.0 vs Drive = 4.0 with hot sine input
        {
            var sig = SinOsc.ar(220) * 0.8;
            var out = FSSteiner.ar(sig, 2000, 0.2, 0, 1.0);
            RecordBuf.ar(out, bufLow, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;

        {
            var sig = SinOsc.ar(220) * 0.8;
            var out = FSSteiner.ar(sig, 2000, 0.2, 0, 4.0);
            RecordBuf.ar(out, bufHigh, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;

        bufLow.loadToFloatArray(action: { |arr| arrLow = arr; });
        bufHigh.loadToFloatArray(action: { |arr| arrHigh = arr; });
        s.sync;

        arrLow = arrLow.copyRange((numSamples * 0.5).asInteger, numSamples - 1);
        arrHigh = arrHigh.copyRange((numSamples * 0.5).asInteger, numSamples - 1);

        rmsLow = (arrLow.squared.sum / arrLow.size).sqrt;
        rmsHigh = (arrHigh.squared.sum / arrHigh.size).sqrt;
        crestLow = arrLow.abs.maxItem / rmsLow;
        crestHigh = arrHigh.abs.maxItem / rmsHigh;

        ("  Crest factor at drive 1.0: " ++ crestLow.round(0.01) ++ ", drive 4.0: " ++ crestHigh.round(0.01)).postln;
        assert.(crestHigh < crestLow, "Higher drive causes waveform compression and crest factor reduction");

        bufLow.free;
        bufHigh.free;
    }.value;

    // -------------------------------------------------------------
    // Test 7: Autonomous Self-Oscillation Limit Cycle (res = 0.95)
    // -------------------------------------------------------------
    "--- Test 7: Autonomous Self-Oscillation Limit Cycle ---".postln;
    {
        var buf = Buffer.alloc(s, numSamples, 1);
        var data, tail, peakAmp;
        s.sync;

        {
            // Initial impulse excitation into self-oscillation (res = 0.95 -> K = 3.42 > 3.0)
            var trig = Impulse.ar(0) * 0.2;
            var out = FSSteiner.ar(trig, 600, 0.95, 0, 1.0);
            RecordBuf.ar(out, buf, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;
        buf.loadToFloatArray(action: { |arr| data = arr; });
        s.sync;

        tail = data.copyRange((numSamples * 0.5).asInteger, numSamples - 1);
        peakAmp = tail.abs.maxItem;

        ("  Self-oscillation sustained limit-cycle peak amplitude: " ++ peakAmp.round(0.001)).postln;
        assert.(tail.every({ |x| x.isNaN.not && (x.abs < 3.0) }), "Self-oscillation remains strictly bounded without NaN/Inf");
        assert.(peakAmp > 0.05, "Self-oscillation produces sustained limit cycle (> 0.05, measured " ++ peakAmp.round(0.001) ++ ")");

        buf.free;
    }.value;

    // -------------------------------------------------------------
    // Test 8: Distinction from Standard Vanilla RLPF
    // -------------------------------------------------------------
    "--- Test 8: Distinction from Standard Vanilla RLPF ---".postln;
    {
        var bufSteiner = Buffer.alloc(s, numSamples, 1);
        var bufRLPF    = Buffer.alloc(s, numSamples, 1);
        var arrSteiner, arrRLPF, rmsDiff;
        s.sync;

        {
            var sig = Saw.ar(110) * 0.3;
            var out = FSSteiner.ar(sig, 1200, 0.6, 0, 1.5);
            RecordBuf.ar(out, bufSteiner, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;

        {
            var sig = Saw.ar(110) * 0.3;
            var out = RLPF.ar(sig, 1200, 0.4);
            RecordBuf.ar(out, bufRLPF, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;

        bufSteiner.loadToFloatArray(action: { |arr| arrSteiner = arr; });
        bufRLPF.loadToFloatArray(action: { |arr| arrRLPF = arr; });
        s.sync;

        rmsDiff = ((arrSteiner - arrRLPF).squared.sum / arrSteiner.size).sqrt;
        ("  RMS difference between FSSteiner and standard RLPF: " ++ rmsDiff.round(0.001)).postln;
        assert.(rmsDiff > 0.05, "FSSteiner exhibits distinctly different spectral/saturation behavior from vanilla RLPF (> 0.05 RMS)");

        bufSteiner.free;
        bufRLPF.free;
    }.value;

    "\n--------------------------------------------------".postln;
    ("Results: " ++ passCount ++ " / " ++ testCount ++ " tests passed.").postln;
    "--------------------------------------------------\n".postln;

    if (passCount == testCount) {
        "ALL FSSTEINER TESTS PASSED.".postln;
        0.exit;
    } {
        "SOME TESTS FAILED.".postln;
        1.exit;
    };
});
