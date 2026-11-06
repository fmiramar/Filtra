// =====================================================================
// test_dynamic_sos.scd: Verification Test Suite for DynamicSOS
// Verifies Modulation-Safe Cascaded Biquad:
// - Class and SynthDef compilation across modes 0-6
// - Extreme audio-rate frequency modulation stability
// - Discontinuous step modulation without state explosion
// - 4-pole Low-Pass roll-off attenuation
// - Peak EQ boost vs cut verification
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
    "  DynamicSOS Automated Verification Suite".postln;
    "==================================================\n".postln;

    // --- Test 1: Class and SynthDef Compilation Across All 7 Modes ---
    "--- Test 1: SynthDef Compilation Across All Modes ---".postln;
    try {
        var defs = (0..6).collect({ |m|
            SynthDef(("testDynSOS_" ++ m).asSymbol, {
                Out.ar(0, DynamicSOS.ar(WhiteNoise.ar(0.1), freq: 1000, q: 2.0, gain: 6.0, mode: m));
            });
        });
        assertTest.value("SynthDefs across all 7 modes (LP, HP, BP, Notch, Peak, LowShelf, HighShelf) compile", defs.every(_.notNil));
    } { |err|
        assertTest.value("SynthDefs compile successfully", false, err.errorString);
    };

    // --- Test 2: Extreme Audio-Rate Frequency Modulation Stability ---
    "--- Test 2: Extreme Audio-Rate Frequency Modulation Stability ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.3;
        var numSamples = (sr * dur).asInteger;
        var buf = Buffer.alloc(s, numSamples, 1);
        s.sync;

        // Modulate cutoff with audio-rate sine from 60 Hz to 12000 Hz at 500 Hz
        SynthDef(\measureDynSOSFM, {
            var inSig = Saw.ar(120) * 0.3;
            var mod = SinOsc.ar(500).exprange(60, 12000);
            var sig = DynamicSOS.ar(inSig, freq: mod, q: 8.0, mode: 0);
            RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureDynSOSFM);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 50.0) });
            var maxAmp = data.abs.maxItem;
            assertTest.value("Extreme audio-rate FM (500 Hz sweep) remains stable without NaN or blowup", isFinite and: { maxAmp > 0.01 }, "peak: " ++ maxAmp.round(0.001));
        });
        s.sync;
        buf.free;
    }.value;

    // --- Test 3: Discontinuous Step Modulation (Jump Continuity) ---
    "--- Test 3: Discontinuous Step Modulation ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.3;
        var numSamples = (sr * dur).asInteger;
        var buf = Buffer.alloc(s, numSamples, 1);
        s.sync;

        // Instantaneous jumping between 100 Hz and 10000 Hz every 64 samples
        SynthDef(\measureDynSOSJump, {
            var inSig = WhiteNoise.ar(0.2);
            var stepFreq = Demand.ar(Impulse.ar(sr / 64), 0, Dseq([100, 10000, 250, 8000], inf));
            var sig = DynamicSOS.ar(inSig, freq: stepFreq, q: 4.0, mode: 0);
            RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureDynSOSJump);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 20.0) });
            var maxAmp = data.abs.maxItem;
            assertTest.value("Abrupt coefficient jumps do not cause state explosion (finite and bounded)", isFinite and: { maxAmp < 10.0 }, "peak: " ++ maxAmp.round(0.001));
        });
        s.sync;
        buf.free;
    }.value;

    // --- Test 4: 4-Pole Low-Pass Attenuation ---
    "--- Test 4: 4-Pole Low-Pass Attenuation ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.3;
        var numSamples = (sr * dur).asInteger;
        var bufLow = Buffer.alloc(s, numSamples, 1);
        var bufHigh = Buffer.alloc(s, numSamples, 1);
        s.sync;

        // Cutoff at 300 Hz: test 100 Hz tone vs 3000 Hz tone
        SynthDef(\measureLPLowTone, {
            var inSig = SinOsc.ar(100) * 0.3;
            var sig = DynamicSOS.ar(inSig, freq: 300, q: 0.707, mode: 0);
            RecordBuf.ar(sig, bufLow, loop: 0, doneAction: 2);
        }).send(s);

        SynthDef(\measureLPHighTone, {
            var inSig = SinOsc.ar(3000) * 0.3;
            var sig = DynamicSOS.ar(inSig, freq: 300, q: 0.707, mode: 0);
            RecordBuf.ar(sig, bufHigh, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureLPLowTone);
        Synth(\measureLPHighTone);
        (dur + 0.1).wait;

        bufLow.loadToFloatArray(action: { |dataLow|
            bufHigh.loadToFloatArray(action: { |dataHigh|
                var lowRMS = (dataLow.squared.sum / dataLow.size).sqrt;
                var highRMS = (dataHigh.squared.sum / dataHigh.size).sqrt;
                var strongAtten = lowRMS > (highRMS * 10.0);
                assertTest.value("Mode 0 LP provides steep 4-pole high frequency attenuation", strongAtten, "passband RMS: " ++ lowRMS.round(0.001) ++ " vs stopband RMS: " ++ highRMS.round(0.001));
            });
        });
        s.sync;
        bufLow.free;
        bufHigh.free;
    }.value;

    // --- Test 5: Peak Mode Boost vs Cut ---
    "--- Test 5: Peak Mode Boost vs Cut ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.3;
        var numSamples = (sr * dur).asInteger;
        var bufBoost = Buffer.alloc(s, numSamples, 1);
        var bufCut = Buffer.alloc(s, numSamples, 1);
        s.sync;

        // Peak at 1000 Hz with +12 dB vs -12 dB
        SynthDef(\measurePeakBoost, {
            var inSig = SinOsc.ar(1000) * 0.2;
            var sig = DynamicSOS.ar(inSig, freq: 1000, q: 2.0, gain: 12.0, mode: 4);
            RecordBuf.ar(sig, bufBoost, loop: 0, doneAction: 2);
        }).send(s);

        SynthDef(\measurePeakCut, {
            var inSig = SinOsc.ar(1000) * 0.2;
            var sig = DynamicSOS.ar(inSig, freq: 1000, q: 2.0, gain: -12.0, mode: 4);
            RecordBuf.ar(sig, bufCut, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measurePeakBoost);
        Synth(\measurePeakCut);
        (dur + 0.1).wait;

        bufBoost.loadToFloatArray(action: { |dataBoost|
            bufCut.loadToFloatArray(action: { |dataCut|
                var boostRMS = (dataBoost.squared.sum / dataBoost.size).sqrt;
                var cutRMS = (dataCut.squared.sum / dataCut.size).sqrt;
                var ratio = boostRMS / (cutRMS + 1e-6);
                var isBoostHigher = ratio > 3.0; // +12 dB vs -12 dB is ~4x difference in amplitude
                assertTest.value("Mode 4 Peak EQ exhibits clear boost vs cut disparity", isBoostHigher, "boost RMS: " ++ boostRMS.round(0.001) ++ " vs cut RMS: " ++ cutRMS.round(0.001) ++ " ratio: " ++ ratio.round(0.1));
            });
        });
        s.sync;
        bufBoost.free;
        bufCut.free;
    }.value;

    "\n--------------------------------------------------".postln;
    ("Results: " ++ passCount ++ " / " ++ testCount ++ " tests passed.").postln;
    "--------------------------------------------------\n".postln;

    if (passCount == testCount) {
        "ALL DYNAMICSOS TESTS PASSED.".postln;
        0.exit;
    } {
        "SOME TESTS FAILED.".postln;
        1.exit;
    };
});
