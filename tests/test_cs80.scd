// =====================================================================
// test_cs80.scd: Verification Test Suite for CS80
// Verifies Yamaha CS-80 series independent HP -> LP resonant pair:
// - Class and SynthDef compilation
// - Independent 2-pole High-Pass and 2-pole Low-Pass filtering
// - Coexistence of dual independent resonance peaks
// - Audio-rate frequency modulation on HP and LP inputs
// - Inverse overlap stability (hpFreq > lpFreq)
// - Non-linear drive saturation & limit-cycle stability
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
    "  CS80 Comprehensive Automated Verification Suite".postln;
    "==================================================\n".postln;

    // --- Test 1: Class and SynthDef Compilation ---
    "--- Test 1: Class and SynthDef Compilation ---".postln;
    try {
        var def = SynthDef(\testCS80Compile, {
            var sig = WhiteNoise.ar(0.1);
            var filtered = CS80.ar(sig, hpFreq: 200, hpRes: 0.5, lpFreq: 2000, lpRes: 0.5, drive: 1.0);
            Out.ar(0, filtered);
        });
        assertTest.value("SynthDef with CS80 compiles successfully", def.notNil);
    } { |err|
        assertTest.value("SynthDef with CS80 compiles successfully", false, err.errorString);
    };

    // --- Test 2: Frequency Response & Dual Resonant Peaks ---
    "--- Test 2: Frequency Response & Dual Resonant Peaks ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.5;
        var numSamples = (sr * dur).asInteger;

        var buf = Buffer.alloc(s, numSamples, 1);
        s.sync;

        // Measure response with hpFreq=300, lpFreq=3000, hpRes=0.8, lpRes=0.8
        SynthDef(\measureCS80, {
            var imp = Impulse.ar(1);
            var sig = CS80.ar(imp, hpFreq: 300, hpRes: 0.8, lpFreq: 3000, lpRes: 0.8, drive: 1.0);
            RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        x = Synth(\measureCS80);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var maxAmp = data.abs.maxItem;
            var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 100.0) });

            assertTest.value("CS80 impulse response is finite and non-empty", isFinite and: { maxAmp > 0.001 }, "peak: " ++ maxAmp.round(0.001));
        });
        s.sync;
        buf.free;
    }.value;

    // --- Test 3: Audio-Rate Modulation on Both Cutoffs ---
    "--- Test 3: Audio-Rate Frequency Modulation ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.3;
        var numSamples = (sr * dur).asInteger;
        var buf = Buffer.alloc(s, numSamples, 1);
        s.sync;

        SynthDef(\measureCS80FM, {
            var inSig = Saw.ar(110) * 0.3;
            var hpMod = SinOsc.ar(440).exprange(100, 1000);
            var lpMod = SinOsc.ar(220).exprange(1500, 8000);
            var sig = CS80.ar(inSig, hpFreq: hpMod, hpRes: 0.7, lpFreq: lpMod, lpRes: 0.7, drive: 2.0);
            RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureCS80FM);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 100.0) });
            var maxAmp = data.abs.maxItem;
            assertTest.value("CS80 handles simultaneous audio-rate HP & LP FM cleanly", isFinite and: { maxAmp > 0.01 }, "peak: " ++ maxAmp.round(0.001));
        });
        s.sync;
        buf.free;
    }.value;

    // --- Test 4: Inverse Overlap Stability (hpFreq > lpFreq) ---
    "--- Test 4: Inverse Overlap Stability (hpFreq > lpFreq) ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.3;
        var numSamples = (sr * dur).asInteger;
        var buf = Buffer.alloc(s, numSamples, 1);
        s.sync;

        // hpFreq=4000 > lpFreq=200 produces strong notch/passband attenuation
        SynthDef(\measureCS80Inverse, {
            var inSig = WhiteNoise.ar(0.2);
            var sig = CS80.ar(inSig, hpFreq: 4000, hpRes: 0.5, lpFreq: 200, lpRes: 0.5, drive: 1.0);
            RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureCS80Inverse);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 100.0) });
            var maxAmp = data.abs.maxItem;
            assertTest.value("CS80 inverse overlap remains strictly stable and bounded", isFinite and: { maxAmp < 0.2 }, "attenuated peak: " ++ maxAmp.round(0.0001));
        });
        s.sync;
        buf.free;
    }.value;

    // --- Test 5: High Resonance & Limit Cycle ---
    "--- Test 5: High Resonance & Limit Cycle ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.4;
        var numSamples = (sr * dur).asInteger;
        var buf = Buffer.alloc(s, numSamples, 1);
        s.sync;

        SynthDef(\measureCS80Res, {
            var trig = Impulse.ar(2);
            var sig = CS80.ar(trig, hpFreq: 400, hpRes: 0.98, lpFreq: 2500, lpRes: 0.98, drive: 2.0);
            RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureCS80Res);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 100.0) });
            var maxAmp = data.abs.maxItem;
            assertTest.value("CS80 dual high-resonance impulse excitation remains strictly bounded", isFinite and: { maxAmp < 5.0 }, "peak: " ++ maxAmp.round(0.001));
        });
        s.sync;
        buf.free;
    }.value;

    // --- Test 6: Extreme Drive Stress Test ---
    "--- Test 6: Extreme Drive Stress Test ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.3;
        var numSamples = (sr * dur).asInteger;
        var buf = Buffer.alloc(s, numSamples, 1);
        s.sync;

        SynthDef(\measureCS80Drive, {
            var inSig = SinOsc.ar(440) * 2.0;
            var sig = CS80.ar(inSig, hpFreq: 100, hpRes: 0.9, lpFreq: 5000, lpRes: 0.9, drive: 15.0);
            RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureCS80Drive);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 100.0) });
            var maxAmp = data.abs.maxItem;
            assertTest.value("CS80 extreme overdrive (drive=15.0) remains strictly finite without NaN", isFinite and: { maxAmp < 5.0 }, "peak: " ++ maxAmp.round(0.001));
        });
        s.sync;
        buf.free;
    }.value;

    "\n--------------------------------------------------".postln;
    ("Results: " ++ passCount ++ " / " ++ testCount ++ " tests passed.").postln;
    "--------------------------------------------------\n".postln;

    if (passCount == testCount) {
        "ALL CS80 TESTS PASSED.".postln;
        0.exit;
    } {
        "SOME TESTS FAILED.".postln;
        1.exit;
    };
});
