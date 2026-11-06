// =====================================================================
// test_fspolivoks.scd: Unit Verification Test Suite for FSPolivoks Stage P1
// Verifies Formanta Polivoks linearized 2-stage state-variable VCF
// across Low-Pass (mode 0) and Band-Pass (mode 1), resonance peaking,
// audio-rate FM stability, impulse response, and distinctness vs RLPF.
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
    "  FSPolivoks Stage P1 Verification Suite         ".postln;
    "==================================================\n".postln;

    // -------------------------------------------------------------
    // Test 1: Class and SynthDef graph compilation
    // -------------------------------------------------------------
    "--- Test 1: Class and SynthDef Compilation ---".postln;
    {
        var defLP = SynthDef(\test_polivoks_lp, { |out=0|
            var sig = FSPolivoks.ar(WhiteNoise.ar(0.1), 1000, 0.3, 0, 1.0);
            Out.ar(out, sig);
        });
        var defBP = SynthDef(\test_polivoks_bp, { |out=0|
            var sig = FSPolivoks.ar(WhiteNoise.ar(0.1), 1000, 0.3, 1, 1.0);
            Out.ar(out, sig);
        });

        assert.(defLP.notNil, "SynthDef with FSPolivoks (LP mode 0) compiles");
        assert.(defBP.notNil, "SynthDef with FSPolivoks (BP mode 1) compiles");
    }.value;

    // -------------------------------------------------------------
    // Test 2: Frequency Response & Slope Verification (LP, BP)
    // -------------------------------------------------------------
    "--- Test 2: Asymptotic Slopes & Frequency Response ---".postln;
    {
        var measureRMS = { |freq, filterMode, fc, res, drive=1.0|
            var buf = Buffer.alloc(s, numSamples, 1);
            var val;
            s.sync;
            {
                var sig = SinOsc.ar(freq) * 0.1;
                var flt = FSPolivoks.ar(sig, fc, res, filterMode, drive);
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
        assert.(lp_slope < -10.0 && lp_slope > -14.5, "FSPolivoks LP exhibits expected ~ -12 dB/octave 2-pole slope (measured " ++ lp_slope.round(0.1) ++ " dB/oct)");

        // BP Mode 1: Cutoff 1000 Hz, res = 0.5
        bp_low    = measureRMS.(250, 1, 1000, 0.5);
        bp_center = measureRMS.(1000, 1, 1000, 0.5);
        bp_high   = measureRMS.(4000, 1, 1000, 0.5);

        ("  BP (250 Hz): " ++ bp_low.round(0.001) ++ ", Center (1000 Hz): " ++ bp_center.round(0.001) ++ ", (4000 Hz): " ++ bp_high.round(0.001)).postln;
        assert.(bp_center > (bp_low * 2.0) && (bp_center > (bp_high * 2.0)), "FSPolivoks BP exhibits clear bandpass peaking at cutoff");

        // Resonance Peaking Gain Test: fc = 1000 Hz, test frequency = 1000 Hz
        res_low  = measureRMS.(1000, 0, 1000, 0.0);
        res_high = measureRMS.(1000, 0, 1000, 0.95);
        res_gain_db = 20.0 * log10(res_high / res_low);

        ("  Resonance Gain at 1000 Hz (res=0.0 vs res=0.95): +" ++ res_gain_db.round(0.1) ++ " dB").postln;
        assert.(res_gain_db > 18.0, "Resonance growth exceeds +18 dB from res=0.0 to res=0.95 (measured +" ++ res_gain_db.round(0.1) ++ " dB)");
    }.value;

    // -------------------------------------------------------------
    // Test 3: Audio-Rate Frequency Modulation Stability
    // -------------------------------------------------------------
    "--- Test 3: Audio-Rate FM Stability ---".postln;
    {
        var buf = Buffer.alloc(s, numSamples, 1);
        var hasNaN = false;
        var maxAmp = 0.0;
        s.sync;

        {
            var src = Saw.ar(110) * 0.2;
            var fm = SinOsc.ar(250) * 1500;
            var fc = (2000 + fm).clip(20, 20000);
            var flt = FSPolivoks.ar(src, fc, 0.85, 0, 1.0);
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
        assert.(hasNaN.not && (maxAmp < 10.0), "Audio-rate FM runs without NaNs or divergence (peak " ++ maxAmp.round(0.001) ++ ")");
    }.value;

    // -------------------------------------------------------------
    // Test 4: Linear Input Scaling (Stage P1 Property)
    // -------------------------------------------------------------
    "--- Test 4: Linear Input Scaling (Stage P1) ---".postln;
    {
        var getRMS = { |amp|
            var buf = Buffer.alloc(s, numSamples, 1);
            var val;
            s.sync;
            {
                var src = SinOsc.ar(440) * amp;
                var flt = FSPolivoks.ar(src, 1200, 0.5, 0, 1.0);
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

        var rms1 = getRMS.(0.05);
        var rms2 = getRMS.(0.10);
        var ratio = rms2 / rms1;

        ("  Linear scaling ratio (target 2.000): " ++ ratio.round(0.0001)).postln;
        assert.((ratio - 2.0).abs < 0.001, "Stage P1 linear scaling holds exact (ratio: " ++ ratio.round(0.0001) ++ ")");
    }.value;

    // -------------------------------------------------------------
    // Test 5: Fast Wide Cutoff Sweep Stability
    // -------------------------------------------------------------
    "--- Test 5: Fast Cutoff Sweep Stability ---".postln;
    {
        var buf = Buffer.alloc(s, numSamples, 1);
        var hasNaN = false;
        var maxAmp = 0.0;
        s.sync;

        {
            var src = Pulse.ar(80, 0.3) * 0.2;
            var fc = XLine.kr(20, 20000, dur);
            var flt = FSPolivoks.ar(src, fc, 0.9, 0, 1.0);
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
    // Test 6: Impulse Response & Ringing Stability
    // -------------------------------------------------------------
    "--- Test 6: High-Q Impulse Ringing ---".postln;
    {
        var buf = Buffer.alloc(s, numSamples, 1);
        var peakAmp = 0.0;
        var energyEarly = 0.0;
        var energyLate = 0.0;
        s.sync;

        {
            var pulse = Impulse.ar(0) * 1.0;
            var flt = FSPolivoks.ar(pulse, 1000, 0.95, 0, 1.0);
            RecordBuf.ar(flt, buf, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;
        buf.loadToFloatArray(action: { |arr|
            peakAmp = arr.abs.maxItem;
            energyEarly = arr.copyRange(0, 1000).squared.sum;
            energyLate = arr.copyRange(arr.size - 1001, arr.size - 1).squared.sum;
        });
        s.sync;
        buf.free;

        ("  High-Q impulse peak amplitude: " ++ peakAmp.round(0.001)).postln;
        ("  Energy Early: " ++ energyEarly.round(0.001) ++ ", Energy Late: " ++ energyLate.round(0.001)).postln;
        assert.(peakAmp > 0.01 && (energyLate < energyEarly), "High-Q impulse rings and cleanly dissipates energy without divergence");
    }.value;

    // -------------------------------------------------------------
    // Test 7: Distinctness vs Standard RLPF
    // -------------------------------------------------------------
    "--- Test 7: Distinct Behavior vs Standard RLPF ---".postln;
    {
        var bufDiff = Buffer.alloc(s, numSamples, 1);
        var diffRMS = 0.0;
        s.sync;

        {
            var src = Saw.ar(130) * 0.2;
            var polivoksSig = FSPolivoks.ar(src, 1500, 0.6, 0, 1.0);
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
        assert.(diffRMS > 0.008, "FSPolivoks exhibits distinct topological response from generic RLPF (diff RMS: " ++ diffRMS.round(0.001) ++ ")");
    }.value;

    // -------------------------------------------------------------
    // Final Summary
    // -------------------------------------------------------------
    "\n==================================================".postln;
    ("  FSPolivoks Verification Summary: " ++ passCount ++ " / " ++ testCount ++ " tests passed").postln;
    "==================================================\n".postln;

    if (passCount == testCount) {
        "ALL FSPOLIVOKS TESTS PASSED SUCCESSFULLY!".postln;
    } {
        "SOME TESTS FAILED!".postln;
    };

    0.5.wait;
    0.exit;
});
