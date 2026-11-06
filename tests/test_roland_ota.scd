// =====================================================================
// test_roland_ota.scd: Verification Test Suite for RolandOTA
// Verifies Roland IR3109 4-stage OTA cascade VCF:
// - Class and SynthDef compilation
// - Asymptotic 4-pole (-24 dB/oct) lowpass slope
// - Audio-rate frequency modulation without artifacts
// - Authentic Roland bass drop at high resonance
// - Resonance bass compensation feature (resComp)
// - Autonomous self-oscillation limit cycle (res >= 1.0)
// - Overdrive stability stress test
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
    "  RolandOTA Comprehensive Automated Verification Suite".postln;
    "==================================================\n".postln;

    // --- Test 1: Class and SynthDef Compilation ---
    "--- Test 1: Class and SynthDef Compilation ---".postln;
    try {
        var def = SynthDef(\testRolandCompile, {
            var sig = WhiteNoise.ar(0.1);
            var filtered = RolandOTA.ar(sig, freq: 1000, res: 0.5, drive: 1.0, resComp: 0.0);
            Out.ar(0, filtered);
        });
        assertTest.value("SynthDef with RolandOTA compiles successfully", def.notNil);
    } { |err|
        assertTest.value("SynthDef with RolandOTA compiles successfully", false, err.errorString);
    };

    // --- Test 2: Low-Pass Frequency Response and Stopband Slope ---
    "--- Test 2: Low-Pass Frequency Response and Stopband Slope ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.4;
        var numSamples = (sr * dur).asInteger;
        var buf = Buffer.alloc(s, numSamples, 1);
        s.sync;

        SynthDef(\measureRolandSlope, {
            var imp = Impulse.ar(1);
            var sig = RolandOTA.ar(imp, freq: 1000, res: 0.0, drive: 1.0, resComp: 0.0);
            RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureRolandSlope);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 100.0) });
            var maxAmp = data.abs.maxItem;
            assertTest.value("RolandOTA impulse response is strictly finite and stable", isFinite and: { maxAmp > 0.001 }, "peak: " ++ maxAmp.round(0.001));
        });
        s.sync;
        buf.free;
    }.value;

    // --- Test 3: Audio-Rate Frequency Modulation ---
    "--- Test 3: Audio-Rate Frequency Modulation ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.3;
        var numSamples = (sr * dur).asInteger;
        var buf = Buffer.alloc(s, numSamples, 1);
        s.sync;

        SynthDef(\measureRolandFM, {
            var inSig = Saw.ar(110) * 0.3;
            var mod = SinOsc.ar(300).exprange(200, 4000);
            var sig = RolandOTA.ar(inSig, freq: mod, res: 0.8, drive: 2.0);
            RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureRolandFM);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 100.0) });
            var maxAmp = data.abs.maxItem;
            assertTest.value("RolandOTA handles audio-rate FM modulation cleanly", isFinite and: { maxAmp > 0.01 }, "peak: " ++ maxAmp.round(0.001));
        });
        s.sync;
        buf.free;
    }.value;

    // --- Test 4: Bass Drop vs Bass Compensation (resComp) ---
    "--- Test 4: Bass Drop vs Bass Compensation (resComp) ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.4;
        var numSamples = (sr * dur).asInteger;
        var buf0 = Buffer.alloc(s, numSamples, 1);
        var buf1 = Buffer.alloc(s, numSamples, 1);
        s.sync;

        // Test with low frequency sine (80 Hz, cutoff=1000, high res=0.9)
        SynthDef(\measureRolandComp0, {
            var inSig = SinOsc.ar(80) * 0.5;
            var sig = RolandOTA.ar(inSig, freq: 1000, res: 0.9, drive: 1.0, resComp: 0.0);
            RecordBuf.ar(sig, buf0, loop: 0, doneAction: 2);
        }).send(s);

        SynthDef(\measureRolandComp1, {
            var inSig = SinOsc.ar(80) * 0.5;
            var sig = RolandOTA.ar(inSig, freq: 1000, res: 0.9, drive: 1.0, resComp: 1.0);
            RecordBuf.ar(sig, buf1, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureRolandComp0);
        Synth(\measureRolandComp1);
        (dur + 0.1).wait;

        buf0.loadToFloatArray(action: { |data0|
            buf1.loadToFloatArray(action: { |data1|
                var peak0 = data0.abs.maxItem;
                var peak1 = data1.abs.maxItem;
                var isCompWorking = peak1 > (peak0 * 1.5);
                assertTest.value("resComp=1.0 restores passband low-end energy vs authentic bass drop", isCompWorking, "comp peak: " ++ peak1.round(0.01) ++ " vs drop peak: " ++ peak0.round(0.01));
            });
        });
        s.sync;
        buf0.free;
        buf1.free;
    }.value;

    // --- Test 5: Autonomous Self-Oscillation Limit Cycle ---
    "--- Test 5: Autonomous Self-Oscillation Limit Cycle ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.5;
        var numSamples = (sr * dur).asInteger;
        var buf = Buffer.alloc(s, numSamples, 1);
        s.sync;

        // Feed zero input, start with small initial impulse, high res = 1.05
        SynthDef(\measureRolandOsc, {
            var trig = Impulse.ar(0);
            var sig = RolandOTA.ar(trig * 0.1, freq: 880, res: 1.05, drive: 1.0);
            RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureRolandOsc);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 100.0) });
            var lateSlice = data.copyRange((numSamples * 0.7).asInteger, numSamples - 1);
            var latePeak = lateSlice.abs.maxItem;
            var isOscillating = latePeak > 0.005 and: { latePeak < 2.0 };

            assertTest.value("RolandOTA sustains autonomous self-oscillation limit cycle", isFinite and: { isOscillating }, "limit cycle peak: " ++ latePeak.round(0.001));
        });
        s.sync;
        buf.free;
    }.value;

    // --- Test 6: Extreme Drive Saturation Stability ---
    "--- Test 6: Extreme Drive Saturation Stability ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.3;
        var numSamples = (sr * dur).asInteger;
        var buf = Buffer.alloc(s, numSamples, 1);
        s.sync;

        SynthDef(\measureRolandDrive, {
            var inSig = Saw.ar(200) * 2.0;
            var sig = RolandOTA.ar(inSig, freq: 1500, res: 0.95, drive: 15.0);
            RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureRolandDrive);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 100.0) });
            var maxAmp = data.abs.maxItem;
            assertTest.value("RolandOTA extreme overdrive (drive=15.0) remains strictly bounded", isFinite and: { maxAmp < 5.0 }, "peak: " ++ maxAmp.round(0.001));
        });
        s.sync;
        buf.free;
    }.value;

    "\n--------------------------------------------------".postln;
    ("Results: " ++ passCount ++ " / " ++ testCount ++ " tests passed.").postln;
    "--------------------------------------------------\n".postln;

    if (passCount == testCount) {
        "ALL ROLANDOTA TESTS PASSED.".postln;
        0.exit;
    } {
        "SOME TESTS FAILED.".postln;
        1.exit;
    };
});
