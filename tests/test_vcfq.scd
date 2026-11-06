// =====================================================================
// test_vcfq.scd: Verification Test Suite for VCFQ (Serge Variable-Q)
// Verifies Serge-style variable-Q ping resonator and multimode VCF:
// - Class and SynthDef compilation across modes 0-3
// - Dedicated trigger ping impulse excitation (no audio input needed)
// - Dynamic Q ringing duration control
// - Audio-rate frequency modulation
// - High-Q nonlinear AGC stability
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
    "  VCFQ (Serge Variable-Q) Automated Verification Suite".postln;
    "==================================================\n".postln;

    // --- Test 1: Class and SynthDef Compilation Across Modes ---
    "--- Test 1: Class and SynthDef Compilation ---".postln;
    try {
        var def0 = SynthDef(\testVCFQLP, { Out.ar(0, VCFQ.ar(WhiteNoise.ar(0.1), freq: 1000, mode: 0)); });
        var def1 = SynthDef(\testVCFQBP, { Out.ar(0, VCFQ.ar(WhiteNoise.ar(0.1), freq: 1000, mode: 1)); });
        var def2 = SynthDef(\testVCFQHP, { Out.ar(0, VCFQ.ar(WhiteNoise.ar(0.1), freq: 1000, mode: 2)); });
        var def3 = SynthDef(\testVCFQNotch, { Out.ar(0, VCFQ.ar(WhiteNoise.ar(0.1), freq: 1000, mode: 3)); });
        assertTest.value("SynthDefs across all 4 modes (LP, BP, HP, Notch) compile successfully", def0.notNil and: { def1.notNil } and: { def2.notNil } and: { def3.notNil });
    } { |err|
        assertTest.value("SynthDefs compile successfully", false, err.errorString);
    };

    // --- Test 2: Trigger Ping Excitation (Zero Audio In) ---
    "--- Test 2: Trigger Ping Excitation ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.4;
        var numSamples = (sr * dur).asInteger;
        var buf = Buffer.alloc(s, numSamples, 1);
        s.sync;

        // Feed zero audio in, ping with trigger at t = 0
        SynthDef(\measureVCFQPing, {
            var trig = Impulse.ar(1);
            var sig = VCFQ.ar(DC.ar(0), trig: trig, freq: 880, q: 20.0, mode: 1);
            RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureVCFQPing);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 100.0) });
            var maxAmp = data.abs.maxItem;
            assertTest.value("Dedicated trigger input excites acoustic ping resonance without audio input", isFinite and: { maxAmp > 0.05 }, "ping peak: " ++ maxAmp.round(0.001));
        });
        s.sync;
        buf.free;
    }.value;

    // --- Test 3: Dynamic Q Ringing Tail Control ---
    "--- Test 3: Dynamic Q Ringing Tail Control ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.4;
        var numSamples = (sr * dur).asInteger;
        var bufLowQ = Buffer.alloc(s, numSamples, 1);
        var bufHighQ = Buffer.alloc(s, numSamples, 1);
        s.sync;

        SynthDef(\measureLowQ, {
            var trig = Impulse.ar(0);
            var sig = VCFQ.ar(DC.ar(0), trig: trig, freq: 600, q: 2.0, mode: 1);
            RecordBuf.ar(sig, bufLowQ, loop: 0, doneAction: 2);
        }).send(s);

        SynthDef(\measureHighQ, {
            var trig = Impulse.ar(0);
            var sig = VCFQ.ar(DC.ar(0), trig: trig, freq: 600, q: 35.0, mode: 1);
            RecordBuf.ar(sig, bufHighQ, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureLowQ);
        Synth(\measureHighQ);
        (dur + 0.1).wait;

        bufLowQ.loadToFloatArray(action: { |dataLow|
            bufHighQ.loadToFloatArray(action: { |dataHigh|
                var lateWindowStart = (numSamples * 0.5).asInteger;
                var lowLateRMS = (dataLow.copyRange(lateWindowStart, numSamples - 1).squared.sum).sqrt;
                var highLateRMS = (dataHigh.copyRange(lateWindowStart, numSamples - 1).squared.sum).sqrt;
                var isLonger = highLateRMS > (lowLateRMS * 4.0);

                assertTest.value("High Q=35 rings substantially longer than Low Q=2", isLonger, "high late energy: " ++ highLateRMS.round(0.001) ++ " vs low: " ++ lowLateRMS.round(0.001));
            });
        });
        s.sync;
        bufLowQ.free;
        bufHighQ.free;
    }.value;

    // --- Test 4: Audio-Rate Frequency Modulation ---
    "--- Test 4: Audio-Rate Frequency Modulation ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.3;
        var numSamples = (sr * dur).asInteger;
        var buf = Buffer.alloc(s, numSamples, 1);
        s.sync;

        SynthDef(\measureVCFQFM, {
            var inSig = Saw.ar(100) * 0.2;
            var mod = SinOsc.ar(250).exprange(300, 3000);
            var sig = VCFQ.ar(inSig, trig: 0, freq: mod, q: 15.0, mode: 1);
            RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureVCFQFM);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 100.0) });
            var maxAmp = data.abs.maxItem;
            assertTest.value("VCFQ handles audio-rate FM modulation cleanly", isFinite and: { maxAmp > 0.01 }, "peak: " ++ maxAmp.round(0.001));
        });
        s.sync;
        buf.free;
    }.value;

    // --- Test 5: High-Q AGC Saturation Stability ---
    "--- Test 5: High-Q AGC Saturation Stability ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.3;
        var numSamples = (sr * dur).asInteger;
        var buf = Buffer.alloc(s, numSamples, 1);
        s.sync;

        SynthDef(\measureVCFQAGC, {
            var inSig = Pulse.ar(55, 0.5) * 2.0;
            var sig = VCFQ.ar(inSig, trig: Impulse.ar(4), freq: 800, q: 45.0, drive: 5.0, mode: 1);
            RecordBuf.ar(sig, buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureVCFQAGC);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 100.0) });
            var maxAmp = data.abs.maxItem;
            assertTest.value("VCFQ extreme Q=45 and drive=5.0 remain strictly bounded by AGC without NaN", isFinite and: { maxAmp < 10.0 }, "peak: " ++ maxAmp.round(0.001));
        });
        s.sync;
        buf.free;
    }.value;

    "\n--------------------------------------------------".postln;
    ("Results: " ++ passCount ++ " / " ++ testCount ++ " tests passed.").postln;
    "--------------------------------------------------\n".postln;

    if (passCount == testCount) {
        "ALL VCFQ TESTS PASSED.".postln;
        0.exit;
    } {
        "SOME TESTS FAILED.".postln;
        1.exit;
    };
});
