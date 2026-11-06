// =====================================================================
// test_dispersion.scd: Verification Test Suite for Dispersion
// Verifies 4-stage cascaded 2nd-order TPT all-pass dispersion filter:
// - Exact flat magnitude preservation across audio frequencies
// - Temporal impulse dispersion and Parseval energy conservation
// - Frequency-dependent phase shift / group delay
// - Fast parameter sweeps and audio-rate modulation stability
// - High-Q concentrated resonance stability (spread = 0.0)
// Reference: Abel and Smith (DAFx 2006)
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
    "  Dispersion Verification Suite                ".postln;
    "==================================================\n".postln;

    // -------------------------------------------------------------
    // Test 1: Class and SynthDef graph compilation
    // -------------------------------------------------------------
    "--- Test 1: Class and SynthDef Compilation ---".postln;
    {
        var def = SynthDef(\test_dispersion_def, { |out=0|
            var sig = Dispersion.ar(WhiteNoise.ar(0.1), 1500, 1.0, 2.0);
            Out.ar(out, sig);
        });

        assert.(def.notNil, "SynthDef with Dispersion compiles");
    }.value;

    // -------------------------------------------------------------
    // Test 2: Flat Magnitude Preservation Across Frequencies
    // -------------------------------------------------------------
    "--- Test 2: Flat Magnitude Response Preservation ---".postln;
    {
        var measureGain = { |testFreq, centerFreq, spreadVal, qVal|
            var bufIn = Buffer.alloc(s, numSamples, 1);
            var bufOut = Buffer.alloc(s, numSamples, 1);
            var rmsIn, rmsOut;
            s.sync;

            {
                var src = SinOsc.ar(testFreq) * 0.2;
                var flt = Dispersion.ar(src, centerFreq, spreadVal, qVal);
                RecordBuf.ar(src, bufIn, loop: 0, doneAction: 2);
                RecordBuf.ar(flt, bufOut, loop: 0, doneAction: 0);
                Silent.ar;
            }.play;

            dur.wait;
            bufIn.loadToFloatArray(action: { |arr|
                var tail = arr.copyRange((numSamples * 0.5).asInteger, numSamples - 1);
                rmsIn = (tail.squared.sum / tail.size).sqrt;
            });
            bufOut.loadToFloatArray(action: { |arr|
                var tail = arr.copyRange((numSamples * 0.5).asInteger, numSamples - 1);
                rmsOut = (tail.squared.sum / tail.size).sqrt;
            });
            s.sync;
            bufIn.free;
            bufOut.free;

            rmsOut / (rmsIn + 1e-9);
        };

        var g100   = measureGain.(100, 1500, 1.0, 2.0);
        var g500   = measureGain.(500, 1500, 1.0, 2.0);
        var g1500  = measureGain.(1500, 1500, 1.0, 2.0); // Exactly at center frequency
        var g4000  = measureGain.(4000, 1500, 1.0, 2.0);
        var g10000 = measureGain.(10000, 1500, 1.0, 2.0);

        ("  Gain at 100 Hz: " ++ g100.round(0.001) ++ ", 500 Hz: " ++ g500.round(0.001)).postln;
        ("  Gain at 1500 Hz (Center): " ++ g1500.round(0.001) ++ ", 4000 Hz: " ++ g4000.round(0.001) ++ ", 10000 Hz: " ++ g10000.round(0.001)).postln;

        assert.((g100 - 1.0).abs < 0.01, "Magnitude is flat at 100 Hz (gain " ++ g100.round(0.001) ++ ")");
        assert.((g500 - 1.0).abs < 0.01, "Magnitude is flat at 500 Hz (gain " ++ g500.round(0.001) ++ ")");
        assert.((g1500 - 1.0).abs < 0.01, "Magnitude is flat at 1500 Hz (center, gain " ++ g1500.round(0.001) ++ ")");
        assert.((g4000 - 1.0).abs < 0.01, "Magnitude is flat at 4000 Hz (gain " ++ g4000.round(0.001) ++ ")");
        assert.((g10000 - 1.0).abs < 0.01, "Magnitude is flat at 10000 Hz (gain " ++ g10000.round(0.001) ++ ")");
    }.value;

    // -------------------------------------------------------------
    // Test 3: Temporal Impulse Dispersion & Parseval Energy Conservation
    // -------------------------------------------------------------
    "--- Test 3: Impulse Temporal Dispersion & Energy Conservation ---".postln;
    {
        var buf = Buffer.alloc(s, numSamples, 1);
        var energy = 0.0;
        var peak = 0.0;
        var dispersedCount = 0;
        s.sync;

        {
            var pulse = Impulse.ar(0) * 1.0;
            var flt = Dispersion.ar(pulse, 1500, 1.5, 4.0);
            RecordBuf.ar(flt, buf, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;
        buf.loadToFloatArray(action: { |arr|
            energy = arr.squared.sum;
            peak = arr.abs.maxItem;
            arr.do({ |v|
                if (v.abs > 0.01) { dispersedCount = dispersedCount + 1; };
            });
        });
        s.sync;
        buf.free;

        ("  Input pulse energy: 1.000, Dispersed energy: " ++ energy.round(0.0001)).postln;
        ("  Dispersed pulse duration: " ++ dispersedCount ++ " samples (peak " ++ peak.round(0.001) ++ ")").postln;

        assert.((energy - 1.0).abs < 0.002, "Parseval's energy conservation holds (energy " ++ energy.round(0.0001) ++ ")");
        assert.(dispersedCount > 25, "1-sample pulse is temporally dispersed over " ++ dispersedCount ++ " samples");
    }.value;

    // -------------------------------------------------------------
    // Test 4: Phase Shift / Group Delay Distinctness
    // -------------------------------------------------------------
    "--- Test 4: Audible Phase Shift / Difference vs Dry Signal ---".postln;
    {
        var bufDiff = Buffer.alloc(s, numSamples, 1);
        var diffRMS = 0.0;
        s.sync;

        {
            var src = Saw.ar(130) * 0.25;
            var flt = Dispersion.ar(src, 1200, 1.0, 3.0);
            var diff = src - flt;
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

        ("  RMS Difference vs Dry Signal: " ++ diffRMS.round(0.001)).postln;
        assert.(diffRMS > 0.05, "Dispersion creates distinct phase shift / group delay (diff RMS " ++ diffRMS.round(0.001) ++ ")");
    }.value;

    // -------------------------------------------------------------
    // Test 5: Continuous Parameter Sweep Stability
    // -------------------------------------------------------------
    "--- Test 5: Fast Parameter Sweep Stability ---".postln;
    {
        var buf = Buffer.alloc(s, numSamples, 1);
        var hasNaN = false;
        var maxAmp = 0.0;
        s.sync;

        {
            var src = Pulse.ar(90, 0.3) * 0.25;
            var centerSweep = XLine.kr(100, 12000, dur);
            var flt = Dispersion.ar(src, centerSweep, 1.5, 4.0);
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

        ("  Fast sweep peak amplitude: " ++ maxAmp.round(0.001)).postln;
        assert.(hasNaN.not && (maxAmp < 5.0) && (maxAmp > 0.05), "Fast continuous center sweep remains stable and bounded");
    }.value;

    // -------------------------------------------------------------
    // Test 6: Audio-Rate Frequency Modulation Stability
    // -------------------------------------------------------------
    "--- Test 6: Audio-Rate Center Modulation ---".postln;
    {
        var buf = Buffer.alloc(s, numSamples, 1);
        var hasNaN = false;
        var maxAmp = 0.0;
        s.sync;

        {
            var src = Saw.ar(80) * 0.25;
            var mod = SinOsc.ar(250) * 1500;
            var flt = Dispersion.ar(src, (2500 + mod).clip(50, 18000), 1.0, 3.0);
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

        ("  Audio FM peak amplitude: " ++ maxAmp.round(0.001)).postln;
        assert.(hasNaN.not && (maxAmp < 5.0), "Audio-rate center frequency modulation runs stably");
    }.value;

    // -------------------------------------------------------------
    // Test 7: Concentrated Resonance (spread = 0.0, high Q)
    // -------------------------------------------------------------
    "--- Test 7: Concentrated Resonance (spread = 0.0) ---".postln;
    {
        var buf = Buffer.alloc(s, numSamples, 1);
        var hasNaN = false;
        var maxAmp = 0.0;
        s.sync;

        {
            var pulse = Impulse.ar(0) * 1.0;
            var flt = Dispersion.ar(pulse, 2000, 0.0, 10.0);
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

        ("  Concentrated peak amplitude: " ++ maxAmp.round(0.001)).postln;
        assert.(hasNaN.not && (maxAmp < 10.0) && (maxAmp > 0.05), "Concentrated allpass sections (spread = 0.0, Q = 10.0) ring stably without blowup");
    }.value;

    // -------------------------------------------------------------
    // Final Summary
    // -------------------------------------------------------------
    "\n==================================================".postln;
    ("  Dispersion Verification Summary: " ++ passCount ++ " / " ++ testCount ++ " tests passed").postln;
    "==================================================\n".postln;

    if (passCount == testCount) {
        "ALL DISPERSION TESTS PASSED SUCCESSFULLY!".postln;
    } {
        "SOME TESTS FAILED!".postln;
    };

    0.5.wait;
    0.exit;
});
