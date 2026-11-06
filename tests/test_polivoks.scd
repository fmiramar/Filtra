// =====================================================================
// test_fspolivoks.scd: Verification Test Suite for Polivoks (Stages P1 & P2)
// Verifies Formanta Polivoks VCF:
// - Stage P1: Linear small-signal 2-stage state-variable integrator cascade
// - Stage P2: Bounded K140UD12 op-amp transconductance saturation & limit cycle
// - Mode 0: Low-Pass (12 dB/oct)
// - Mode 1: Band-Pass (6 dB/oct)
// Reference: Vladimir Kuzmin (1982), Formanta Polivoks synthesizer VCF
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
    "  Polivoks Stages P1 & P2 Verification Suite   ".postln;
    "==================================================\n".postln;

    // -------------------------------------------------------------
    // Test 1: Class and SynthDef graph compilation
    // -------------------------------------------------------------
    "--- Test 1: Class and SynthDef Compilation ---".postln;
    {
        var defLP = SynthDef(\test_polivoks_lp, { |out=0|
            var sig = Polivoks.ar(WhiteNoise.ar(0.1), 1000, 0.3, 0, 1.0);
            Out.ar(out, sig);
        });
        var defBP = SynthDef(\test_polivoks_bp, { |out=0|
            var sig = Polivoks.ar(WhiteNoise.ar(0.1), 1000, 0.3, 1, 1.0);
            Out.ar(out, sig);
        });

        assert.(defLP.notNil, "SynthDef with Polivoks (LP mode 0) compiles");
        assert.(defBP.notNil, "SynthDef with Polivoks (BP mode 1) compiles");
    }.value;

    // -------------------------------------------------------------
    // Test 2: Small-Signal Convergence (Stage P1 vs Stage P2)
    // -------------------------------------------------------------
    "--- Test 2: Small-Signal Convergence (Stage P1 vs P2) ---".postln;
    {
        var bufDiff = Buffer.alloc(s, numSamples, 1);
        var diffRMS = 0.0;
        s.sync;

        {
            var src = SinOsc.ar(440) * 0.0001; // Small signal
            var sigLin = Polivoks.ar(src, 1200, 0.5, 0, drive: 0.0);
            var sigNL  = Polivoks.ar(src, 1200, 0.5, 0, drive: 1.0);
            var diff = sigNL - sigLin;
            RecordBuf.ar(diff, bufDiff, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;
        bufDiff.loadToFloatArray(action: { |arr|
            var tail = arr.copyRange((numSamples * 0.5).asInteger, numSamples - 1);
            diffRMS = (tail.squared.sum / tail.size).sqrt;
        });
        s.sync;
        bufDiff.free;

        ("  Small-Signal Diff RMS (P1 vs P2): " ++ diffRMS.asString).postln;
        assert.(diffRMS < 1e-6, "Stage P2 nonlinear model converges to Stage P1 linear model at small signal (diff " ++ diffRMS.asString ++ ")");
    }.value;

    // -------------------------------------------------------------
    // Test 3: Frequency Response & Slope Verification (LP, BP)
    // -------------------------------------------------------------
    "--- Test 3: Asymptotic Slopes & Frequency Response ---".postln;
    {
        var measureRMS = { |freq, filterMode, fc, res, drive=0.0|
            var buf = Buffer.alloc(s, numSamples, 1);
            var val;
            s.sync;
            {
                var sig = SinOsc.ar(freq) * 0.05;
                var flt = Polivoks.ar(sig, fc, res, filterMode, drive);
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
        assert.(lp_slope < -10.0 && lp_slope > -14.5, "Polivoks LP exhibits expected ~ -12 dB/octave 2-pole slope (measured " ++ lp_slope.round(0.1) ++ " dB/oct)");

        // BP Mode 1: Cutoff 1000 Hz, res = 0.5
        bp_low    = measureRMS.(250, 1, 1000, 0.5);
        bp_center = measureRMS.(1000, 1, 1000, 0.5);
        bp_high   = measureRMS.(4000, 1, 1000, 0.5);

        ("  BP (250 Hz): " ++ bp_low.round(0.001) ++ ", Center (1000 Hz): " ++ bp_center.round(0.001) ++ ", (4000 Hz): " ++ bp_high.round(0.001)).postln;
        assert.(bp_center > (bp_low * 2.0) && (bp_center > (bp_high * 2.0)), "Polivoks BP exhibits clear bandpass peaking at cutoff");

        // Small-signal resonance gain growth: fc = 1000 Hz, test frequency = 1000 Hz
        res_low  = measureRMS.(1000, 0, 1000, 0.0);
        res_high = measureRMS.(1000, 0, 1000, 0.95);
        res_gain_db = 20.0 * log10(res_high / res_low);

        ("  Resonance Gain at 1000 Hz (res=0.0 vs res=0.95): +" ++ res_gain_db.round(0.1) ++ " dB").postln;
        assert.(res_gain_db > 18.0, "Resonance growth exceeds +18 dB from res=0.0 to res=0.95 (measured +" ++ res_gain_db.round(0.1) ++ " dB)");
    }.value;

    // -------------------------------------------------------------
    // Test 4: Large-Signal Nonlinear Saturation & Crest Factor Compression
    // -------------------------------------------------------------
    "--- Test 4: Nonlinear Saturation & Crest Compression ---".postln;
    {
        var getCrest = { |driveVal|
            var buf = Buffer.alloc(s, numSamples, 1);
            var crest = 0.0;
            s.sync;
            {
                var src = SinOsc.ar(300) * 0.4;
                var flt = Polivoks.ar(src, 1000, 0.4, 0, drive: driveVal);
                RecordBuf.ar(flt, buf, loop: 0, doneAction: 2);
                Silent.ar;
            }.play;
            dur.wait;
            buf.loadToFloatArray(action: { |arr|
                var tail = arr.copyRange((numSamples * 0.5).asInteger, numSamples - 1);
                var peak = tail.abs.maxItem;
                var rms = (tail.squared.sum / tail.size).sqrt;
                crest = peak / (rms + 1e-9);
            });
            s.sync;
            buf.free;
            crest;
        };

        var crestLow = getCrest.(0.5);
        var crestHigh = getCrest.(5.0);

        ("  Crest Factor (drive=0.5): " ++ crestLow.round(0.01) ++ ", (drive=5.0): " ++ crestHigh.round(0.01)).postln;
        assert.(crestHigh < crestLow, "Higher drive compresses sine wave into saturated waveform (crest factor " ++ crestLow.round(0.01) ++ " -> " ++ crestHigh.round(0.01) ++ ")");
    }.value;

    // -------------------------------------------------------------
    // Test 5: Self-Oscillation Limit Cycle (Stage P2)
    // -------------------------------------------------------------
    "--- Test 5: Autonomous Self-Oscillation Limit Cycle ---".postln;
    {
        var buf = Buffer.alloc(s, numSamples, 1);
        var tailRMS = 0.0;
        var tailPeak = 0.0;
        var hasNaN = false;
        s.sync;

        {
            // Initial tiny excitation, then silence
            var trig = Impulse.ar(0) * 0.1;
            var flt = Polivoks.ar(trig, 880, 1.05, 0, drive: 1.0);
            RecordBuf.ar(flt, buf, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;
        buf.loadToFloatArray(action: { |arr|
            var tail = arr.copyRange((numSamples * 0.5).asInteger, numSamples - 1);
            tailRMS = (tail.squared.sum / tail.size).sqrt;
            tailPeak = tail.abs.maxItem;
            arr.do({ |v|
                if (v.isNaN || (v.abs > 50.0)) { hasNaN = true; };
            });
        });
        s.sync;
        buf.free;

        ("  Self-Oscillation Tail Peak: " ++ tailPeak.round(0.001) ++ ", Tail RMS: " ++ tailRMS.round(0.001)).postln;
        assert.(hasNaN.not && (tailRMS > 0.02) && (tailPeak < 2.0), "Polivoks sustains an autonomous, bounded self-oscillation limit cycle at res >= 1.0 (peak " ++ tailPeak.round(0.001) ++ ", RMS " ++ tailRMS.round(0.001) ++ ")");
    }.value;

    // -------------------------------------------------------------
    // Test 6: Audio-Rate FM Stability Under High Drive
    // -------------------------------------------------------------
    "--- Test 6: Audio-Rate FM Stability Under High Drive ---".postln;
    {
        var buf = Buffer.alloc(s, numSamples, 1);
        var hasNaN = false;
        var maxAmp = 0.0;
        s.sync;

        {
            var src = Saw.ar(110) * 0.3;
            var fm = SinOsc.ar(250) * 1500;
            var fc = (2000 + fm).clip(20, 20000);
            var flt = Polivoks.ar(src, fc, 0.9, 0, drive: 2.5);
            RecordBuf.ar(flt, buf, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;
        buf.loadToFloatArray(action: { |arr|
            arr.do({ |v|
                if (v.isNaN || (v.abs > 50.0)) { hasNaN = true; };
                if (v.abs > maxAmp) { maxAmp = v.abs; };
            });
        });
        s.sync;
        buf.free;

        ("  Audio FM Peak Amplitude: " ++ maxAmp.round(0.001)).postln;
        assert.(hasNaN.not && (maxAmp < 10.0), "Audio-rate FM runs without NaNs or divergence under hot drive (peak " ++ maxAmp.round(0.001) ++ ")");
    }.value;

    // -------------------------------------------------------------
    // Test 7: Fast Wide Cutoff Sweep Stability
    // -------------------------------------------------------------
    "--- Test 7: Fast Cutoff Sweep Stability ---".postln;
    {
        var buf = Buffer.alloc(s, numSamples, 1);
        var hasNaN = false;
        var maxAmp = 0.0;
        s.sync;

        {
            var src = Pulse.ar(80, 0.3) * 0.25;
            var fc = XLine.kr(20, 20000, dur);
            var flt = Polivoks.ar(src, fc, 0.95, 0, drive: 1.5);
            RecordBuf.ar(flt, buf, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;
        buf.loadToFloatArray(action: { |arr|
            arr.do({ |v|
                if (v.isNaN || (v.abs > 50.0)) { hasNaN = true; };
                if (v.abs > maxAmp) { maxAmp = v.abs; };
            });
        });
        s.sync;
        buf.free;

        ("  Wide sweep peak amplitude: " ++ maxAmp.round(0.001)).postln;
        assert.(hasNaN.not && (maxAmp < 10.0), "Fast cutoff sweep across audio spectrum remains stable and finite");
    }.value;

    // -------------------------------------------------------------
    // Test 8: High-Q Impulse Ringing & Boundedness
    // -------------------------------------------------------------
    "--- Test 8: High-Q Impulse Ringing ---".postln;
    {
        var buf = Buffer.alloc(s, numSamples, 1);
        var peakAmp = 0.0;
        var hasNaN = false;
        s.sync;

        {
            var pulse = Impulse.ar(0) * 1.0;
            var flt = Polivoks.ar(pulse, 1000, 0.9, 0, drive: 1.0);
            RecordBuf.ar(flt, buf, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;
        buf.loadToFloatArray(action: { |arr|
            peakAmp = arr.abs.maxItem;
            arr.do({ |v|
                if (v.isNaN || (v.abs > 50.0)) { hasNaN = true; };
            });
        });
        s.sync;
        buf.free;

        ("  High-Q impulse peak amplitude: " ++ peakAmp.round(0.001)).postln;
        assert.(hasNaN.not && (peakAmp > 0.01) && (peakAmp < 5.0), "High-Q impulse produces finite, bounded ringing (peak " ++ peakAmp.round(0.001) ++ ")");
    }.value;

    // -------------------------------------------------------------
    // Test 9: Distinct Behavior vs Standard RLPF
    // -------------------------------------------------------------
    "--- Test 9: Distinct Behavior vs Standard RLPF ---".postln;
    {
        var bufDiff = Buffer.alloc(s, numSamples, 1);
        var diffRMS = 0.0;
        s.sync;

        {
            var src = Saw.ar(130) * 0.2;
            var polivoksSig = Polivoks.ar(src, 1500, 0.6, 0, drive: 1.0);
            var rlpfSig = RLPF.ar(src, 1500, 0.4);
            var diff = polivoksSig - rlpfSig;
            RecordBuf.ar(diff, bufDiff, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;
        bufDiff.loadToFloatArray(action: { |arr|
            var tail = arr.copyRange((numSamples * 0.5).asInteger, numSamples - 1);
            diffRMS = (tail.squared.sum / tail.size).sqrt;
        });
        s.sync;
        bufDiff.free;

        ("  RMS Difference vs RLPF: " ++ diffRMS.round(0.001)).postln;
        assert.(diffRMS > 0.008, "Polivoks exhibits distinct topological response from generic RLPF (diff RMS: " ++ diffRMS.round(0.001) ++ ")");
    }.value;

    // -------------------------------------------------------------
    // Final Summary
    // -------------------------------------------------------------
    "\n==================================================".postln;
    ("  Polivoks Verification Summary: " ++ passCount ++ " / " ++ testCount ++ " tests passed").postln;
    "==================================================\n".postln;

    if (passCount == testCount) {
        "ALL FSPOLIVOKS TESTS PASSED SUCCESSFULLY!".postln;
    } {
        "SOME TESTS FAILED!".postln;
    };

    0.5.wait;
    0.exit;
});
