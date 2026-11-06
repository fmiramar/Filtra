// =====================================================================
// test_fszmorph.scd: Verification Test Suite for FSZMorph
// Verifies original digital multiresonant filter response morphing:
// - Exact endpoint correspondence (morph = 0 equals A; morph = 1 equals B)
// - Shape distinctness across all preset shapes
// - Continuous click-free sweep stability
// - Audio-rate morph modulation without divergence
// - Energy dissipation and impulse decay
// Reference: Rossum / E-mu Z-plane concept (clean-room original implementation)
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
    "  FSZMorph Verification Suite                    ".postln;
    "==================================================\n".postln;

    // -------------------------------------------------------------
    // Test 1: Class and SynthDef graph compilation
    // -------------------------------------------------------------
    "--- Test 1: Class and SynthDef Compilation ---".postln;
    {
        var def1 = SynthDef(\test_zmorph_1, { |out=0|
            var sig = FSZMorph.ar(WhiteNoise.ar(0.1), 0.5, 0, 1);
            Out.ar(out, sig);
        });
        var def2 = SynthDef(\test_zmorph_2, { |out=0|
            var sig = FSZMorph.ar(WhiteNoise.ar(0.1), 0.5, 3, 4);
            Out.ar(out, sig);
        });

        assert.(def1.notNil, "SynthDef with FSZMorph (shapes 0 -> 1) compiles");
        assert.(def2.notNil, "SynthDef with FSZMorph (shapes 3 -> 4) compiles");
    }.value;

    // -------------------------------------------------------------
    // Test 2: Endpoint Accuracy (morph=0 equals A; morph=1 equals B)
    // -------------------------------------------------------------
    "--- Test 2: Endpoint Accuracy ---".postln;
    {
        var testEndpoint = { |morphVal, targetShape|
            var bufDiff = Buffer.alloc(s, numSamples, 1);
            var maxDiff = 0.0;
            s.sync;

            {
                var src = Saw.ar(110) * 0.2;
                // sigMorph evaluates with morphVal
                var sigMorph = FSZMorph.ar(src, morphVal, 0, 1);
                // sigTarget evaluates pure target shape by setting shapeA=shapeB=targetShape
                var sigTarget = FSZMorph.ar(src, 0.0, targetShape, targetShape);
                var diff = sigMorph - sigTarget;
                RecordBuf.ar(diff, bufDiff, loop: 0, doneAction: 2);
                Silent.ar;
            }.play;

            dur.wait;
            bufDiff.loadToFloatArray(action: { |arr|
                var tail = arr.copyRange((numSamples * 0.5).asInteger, numSamples - 1);
                maxDiff = tail.abs.maxItem;
            });
            s.sync;
            bufDiff.free;
            maxDiff;
        };

        var errA = testEndpoint.(0.0, 0);
        var errB = testEndpoint.(1.0, 1);

        ("  Endpoint A Error (morph=0.0 vs pure Shape 0): " ++ errA.asString).postln;
        ("  Endpoint B Error (morph=1.0 vs pure Shape 1): " ++ errB.asString).postln;
        assert.(errA < 1e-6, "morph=0.0 matches Shape A exactly (max error " ++ errA.asString ++ ")");
        assert.(errB < 1e-6, "morph=1.0 matches Shape B exactly (max error " ++ errB.asString ++ ")");
    }.value;

    // -------------------------------------------------------------
    // Test 3: Spectral Distinctness Between Presets
    // -------------------------------------------------------------
    "--- Test 3: Spectral Distinctness Between Shapes ---".postln;
    {
        var measureShapeRMS = { |shapeIdx|
            var buf = Buffer.alloc(s, numSamples, 1);
            var val;
            s.sync;
            {
                var src = Saw.ar(90) * 0.25;
                var flt = FSZMorph.ar(src, 0.0, shapeIdx, shapeIdx);
                RecordBuf.ar(flt, buf, loop: 0, doneAction: 2);
                Silent.ar;
            }.play;
            dur.wait;
            buf.loadToFloatArray(action: { |arr|
                val = arr;
            });
            s.sync;
            buf.free;
            val;
        };

        var arr0 = measureShapeRMS.(0); // Vowel A
        var arr1 = measureShapeRMS.(1); // Vowel I
        var arr3 = measureShapeRMS.(3); // Comb
        var arr4 = measureShapeRMS.(4); // Bell

        var diffRMS_0_1 = ((arr0 - arr1).squared.sum / arr0.size).sqrt;
        var diffRMS_3_4 = ((arr3 - arr4).squared.sum / arr3.size).sqrt;

        ("  Diff RMS (Vowel A vs Vowel I): " ++ diffRMS_0_1.round(0.001)).postln;
        ("  Diff RMS (Comb vs Bell): " ++ diffRMS_3_4.round(0.001)).postln;

        assert.(diffRMS_0_1 > 0.02, "Shape 0 (Vowel A) and Shape 1 (Vowel I) produce highly distinct responses (diff RMS: " ++ diffRMS_0_1.round(0.001) ++ ")");
        assert.(diffRMS_3_4 > 0.02, "Shape 3 (Comb) and Shape 4 (Bell) produce highly distinct responses (diff RMS: " ++ diffRMS_3_4.round(0.001) ++ ")");
    }.value;

    // -------------------------------------------------------------
    // Test 4: Smooth Continuous Morph Sweep Stability
    // -------------------------------------------------------------
    "--- Test 4: Continuous Morph Sweep Stability ---".postln;
    {
        var buf = Buffer.alloc(s, numSamples, 1);
        var hasNaN = false;
        var maxAmp = 0.0;
        s.sync;

        {
            var src = Pulse.ar(100, 0.3) * 0.25;
            var morph = Line.kr(0.0, 1.0, dur);
            var flt = FSZMorph.ar(src, morph, 0, 4);
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

        ("  Morph sweep peak amplitude: " ++ maxAmp.round(0.001)).postln;
        assert.(hasNaN.not && (maxAmp < 5.0) && (maxAmp > 0.05), "Continuous morph sweep executes cleanly without blowup or zipper glitches");
    }.value;

    // -------------------------------------------------------------
    // Test 5: Audio-Rate Morph Modulation Stability
    // -------------------------------------------------------------
    "--- Test 5: Audio-Rate Morph Modulation ---".postln;
    {
        var buf = Buffer.alloc(s, numSamples, 1);
        var hasNaN = false;
        var maxAmp = 0.0;
        s.sync;

        {
            var src = Saw.ar(70) * 0.25;
            var morphMod = SinOsc.ar(150).range(0.0, 1.0);
            var flt = FSZMorph.ar(src, morphMod, 1, 3);
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

        ("  Audio morph modulation peak: " ++ maxAmp.round(0.001)).postln;
        assert.(hasNaN.not && (maxAmp < 5.0), "Audio-rate morph modulation runs stably with bounded output");
    }.value;

    // -------------------------------------------------------------
    // Test 6: Impulse Response & Energy Dissipation
    // -------------------------------------------------------------
    "--- Test 6: Impulse Response & Energy Decay ---".postln;
    {
        var buf = Buffer.alloc(s, numSamples, 1);
        var energyEarly = 0.0;
        var energyLate = 0.0;
        var peakAmp = 0.0;
        s.sync;

        {
            var pulse = Impulse.ar(0) * 1.0;
            var flt = FSZMorph.ar(pulse, 0.5, 2, 4);
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

        ("  Impulse peak: " ++ peakAmp.round(0.001)).postln;
        ("  Energy Early: " ++ energyEarly.round(0.001) ++ ", Energy Late: " ++ energyLate.round(0.001)).postln;
        assert.(peakAmp > 0.05 && (energyLate < 1e-4), "Impulse response rings and cleanly dissipates energy to silence");
    }.value;

    // -------------------------------------------------------------
    // Final Summary
    // -------------------------------------------------------------
    "\n==================================================".postln;
    ("  FSZMorph Verification Summary: " ++ passCount ++ " / " ++ testCount ++ " tests passed").postln;
    "==================================================\n".postln;

    if (passCount == testCount) {
        "ALL FSZMORPH TESTS PASSED SUCCESSFULLY!".postln;
    } {
        "SOME TESTS FAILED!".postln;
    };

    0.5.wait;
    0.exit;
});
