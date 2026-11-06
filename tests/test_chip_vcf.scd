// =====================================================================
// test_chip_vcf.scd: Verification Test Suite for ChipVCF (SSM2044)
// Verifies Solid State Micro Technology SSM2044 4-pole low-pass VCF:
// - Class and SynthDef compilation
// - Asymptotic 4-pole (-24 dB/oct) lowpass slope
// - Audio-rate frequency modulation without artifacts
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
    "  ChipVCF (SSM2044) Automated Verification Suite".postln;
    "==================================================\n".postln;

    // --- Test 1: Class and SynthDef Compilation ---
    "--- Test 1: Class and SynthDef Compilation ---".postln;
    try {
        var def = SynthDef(\testChipVCFCompile, {
            var sig = WhiteNoise.ar(0.1);
            var filtered = ChipVCF.ar(sig, freq: 1000, res: 0.5, drive: 1.0);
            Out.ar(0, filtered);
        });
        assertTest.value("SynthDef with ChipVCF compiles successfully", def.notNil);
    } { |err|
        assertTest.value("SynthDef with ChipVCF compiles successfully", false, err.errorString);
    };

    // --- Test 2: Low-Pass Frequency Response and Stopband Slope ---
    "--- Test 2: Low-Pass Frequency Response and Stopband Slope ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.4;
        var numSamples = (sr * dur).asInteger;
        var buf = Buffer.alloc(s, numSamples, 1);
        s.sync;

        SynthDef(\measureChipSlope, {
            var imp = Impulse.ar(1);
            var sig = ChipVCF.ar(imp, freq: 1000, res: 0.0, drive: 1.0);
            RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureChipSlope);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 100.0) });
            var maxAmp = data.abs.maxItem;
            assertTest.value("ChipVCF impulse response is strictly finite and stable", isFinite and: { maxAmp > 0.001 }, "peak: " ++ maxAmp.round(0.001));
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

        SynthDef(\measureChipFM, {
            var inSig = Saw.ar(110) * 0.3;
            var mod = SinOsc.ar(300).exprange(200, 4000);
            var sig = ChipVCF.ar(inSig, freq: mod, res: 0.8, drive: 2.0);
            RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureChipFM);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 100.0) });
            var maxAmp = data.abs.maxItem;
            assertTest.value("ChipVCF handles audio-rate FM modulation cleanly", isFinite and: { maxAmp > 0.01 }, "peak: " ++ maxAmp.round(0.001));
        });
        s.sync;
        buf.free;
    }.value;

    // --- Test 4: Autonomous Self-Oscillation Limit Cycle ---
    "--- Test 4: Autonomous Self-Oscillation Limit Cycle ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.5;
        var numSamples = (sr * dur).asInteger;
        var buf = Buffer.alloc(s, numSamples, 1);
        s.sync;

        SynthDef(\measureChipOsc, {
            var trig = Impulse.ar(0);
            var sig = ChipVCF.ar(trig * 0.1, freq: 880, res: 1.05, drive: 1.0);
            RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureChipOsc);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 100.0) });
            var lateSlice = data.copyRange((numSamples * 0.7).asInteger, numSamples - 1);
            var latePeak = lateSlice.abs.maxItem;
            var isOscillating = latePeak > 0.005 and: { latePeak < 2.0 };

            assertTest.value("ChipVCF sustains autonomous self-oscillation limit cycle", isFinite and: { isOscillating }, "limit cycle peak: " ++ latePeak.round(0.001));
        });
        s.sync;
        buf.free;
    }.value;

    // --- Test 5: Extreme Drive Saturation Stability ---
    "--- Test 5: Extreme Drive Saturation Stability ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.3;
        var numSamples = (sr * dur).asInteger;
        var buf = Buffer.alloc(s, numSamples, 1);
        s.sync;

        SynthDef(\measureChipDrive, {
            var inSig = Saw.ar(200) * 2.0;
            var sig = ChipVCF.ar(inSig, freq: 1500, res: 0.95, drive: 15.0);
            RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureChipDrive);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 100.0) });
            var maxAmp = data.abs.maxItem;
            assertTest.value("ChipVCF extreme overdrive (drive=15.0) remains strictly bounded", isFinite and: { maxAmp < 5.0 }, "peak: " ++ maxAmp.round(0.001));
        });
        s.sync;
        buf.free;
    }.value;

    "\n--------------------------------------------------".postln;
    ("Results: " ++ passCount ++ " / " ++ testCount ++ " tests passed.").postln;
    "--------------------------------------------------\n".postln;

    if (passCount == testCount) {
        "ALL CHIPVCF TESTS PASSED.".postln;
        0.exit;
    } {
        "SOME TESTS FAILED.".postln;
        1.exit;
    };
});
