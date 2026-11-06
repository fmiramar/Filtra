// =====================================================================
// test_formant_morph.scd: Verification Test Suite for FormantMorph
// Verifies coordinated multi-formant vowel bank with continuous log-frequency morphing:
// - Class and SynthDef compilation
// - Audio-rate morph modulation
// - Finite and stable output across all 5 phonetic vowel presets
// - Frequency and bandwidth scaling stability
// =====================================================================

var s;
s = Server.default;

s.waitForBoot({
    var passCount = 0;
    var testCount = 0;
    var assertTest = { |name, condition, details = ""|
        testCount = testCount + 1;
        if (condition) {
            passCount = passCount + 1;
            ("  [PASS] " ++ name ++ if(details.size > 0, " (" ++ details ++ ")", "")).postln;
        } {
            ("  [FAIL] " ++ name ++ if(details.size > 0, " (" ++ details ++ ")", "")).postln;
        };
    };

    "\n==================================================".postln;
    "  FormantMorph Automated Verification Suite".postln;
    "==================================================\n".postln;

    // --- Test 1: Class and SynthDef Compilation ---
    "--- Test 1: Class and SynthDef Compilation ---".postln;
    try {
        var def = SynthDef(\testFormantCompile, {
            var sig = Saw.ar(100) * 0.2;
            var morph = SinOsc.kr(0.5).range(0.0, 1.0);
            var filtered = FormantMorph.ar(sig, morph: morph, vowelA: 0, vowelB: 2);
            Out.ar(0, filtered);
        });
        assertTest.value("SynthDef with FormantMorph compiles successfully", def.notNil);
    } { |err|
        assertTest.value("SynthDef with FormantMorph compiles successfully", false, err.errorString);
    };

    // --- Test 2: Audio-Rate Morph Modulation ---
    "--- Test 2: Audio-Rate Morph Modulation ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.3;
        var numSamples = (sr * dur).asInteger;
        var buf = Buffer.alloc(s, numSamples, 1);
        s.sync;

        SynthDef(\measureFormantFM, {
            var inSig = Saw.ar(110) * 0.25;
            var morphSig = LFTri.ar(20).range(0.0, 1.0);
            var sig = FormantMorph.ar(inSig, morph: morphSig, vowelA: 0, vowelB: 1);
            RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureFormantFM);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 100.0) });
            var maxAmp = data.abs.maxItem;
            assertTest.value("FormantMorph handles fast audio-rate morph modulation cleanly", isFinite and: { maxAmp > 0.01 }, "peak: " ++ maxAmp.round(0.001));
        });
        s.sync;
        buf.free;
    }.value;

    // --- Test 3: Vowel Presets Output Integrity ---
    "--- Test 3: All 5 Vowel Presets ---".postln;
    {
        var allPassed = true;
        5.do { |vIdx|
            var sr = s.sampleRate;
            var dur = 0.1;
            var numSamples = (sr * dur).asInteger;
            var buf = Buffer.alloc(s, numSamples, 1);
            s.sync;

            SynthDef(\measureVowel, {
                var inSig = Saw.ar(110) * 0.2;
                var sig = FormantMorph.ar(inSig, morph: 0.0, vowelA: vIdx, vowelB: vIdx);
                RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
            }).send(s);
            s.sync;

            Synth(\measureVowel);
            (dur + 0.05).wait;

            buf.loadToFloatArray(action: { |data|
                var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 100.0) });
                var maxAmp = data.abs.maxItem;
                if (isFinite.not || (maxAmp < 0.001)) { allPassed = false; };
            });
            s.sync;
            buf.free;
        };
        assertTest.value("All 5 phonetic vowels ([a], [e], [i], [o], [u]) produce stable finite output", allPassed);
    }.value;

    // --- Test 4: Extreme Parameter Scaling Stability ---
    "--- Test 4: Extreme Parameter Scaling Stability ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.2;
        var numSamples = (sr * dur).asInteger;
        var buf = Buffer.alloc(s, numSamples, 1);
        s.sync;

        SynthDef(\measureFormantScale, {
            var inSig = WhiteNoise.ar(0.3);
            var sig = FormantMorph.ar(inSig, morph: 0.5, vowelA: 1, vowelB: 3, freqScale: 3.0, bwScale: 0.2);
            RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureFormantScale);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 100.0) });
            assertTest.value("FormantMorph extreme freqScale=3.0 & sharp Q remains strictly finite", isFinite);
        });
        s.sync;
        buf.free;
    }.value;

    "\n--------------------------------------------------".postln;
    ("Results: " ++ passCount ++ " / " ++ testCount ++ " tests passed.").postln;
    "--------------------------------------------------\n".postln;

    if (passCount == testCount) {
        "ALL FORMANTMORPH TESTS PASSED.".postln;
        0.exit;
    } {
        "SOME TESTS FAILED.".postln;
        1.exit;
    };
});
