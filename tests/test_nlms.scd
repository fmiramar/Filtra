// =====================================================================
// test_nlms.scd: Verification Test Suite for NLMS
// Verifies real-time adaptive Normalized Least-Mean-Squares FIR filter:
// - Class and SynthDef multi-output compilation
// - Real-time system identification & error convergence
// - Invariant behavior with mu = 0
// - Numerical stability during silence (eps protection)
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
    "  NLMS Adaptive Filter Automated Verification Suite".postln;
    "==================================================\n".postln;

    // --- Test 1: Class and SynthDef Compilation ---
    "--- Test 1: Class and SynthDef Compilation ---".postln;
    try {
        var def = SynthDef(\testNLMSCompile, {
            var ref = WhiteNoise.ar(0.1);
            var des = DelayN.ar(ref, 0.001, 0.0005);
            var sigs = NLMS.ar(ref, des, mu: 0.1, eps: 0.001);
            Out.ar(0, sigs[0]);
            Out.ar(1, sigs[1]);
        });
        assertTest.value("SynthDef with multi-output NLMS compiles successfully", def.notNil);
    } { |err|
        assertTest.value("SynthDef with multi-output NLMS compiles successfully", false, err.errorString);
    };

    // --- Test 2: System Identification & Error Reduction ---
    "--- Test 2: System Identification & Error Reduction ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.5;
        var numSamples = (sr * dur).asInteger;
        var bufY = Buffer.alloc(s, numSamples, 1);
        var bufE = Buffer.alloc(s, numSamples, 1);
        s.sync;

        // Target: identify a 5-sample delayed reference
        SynthDef(\measureNLMSConvergence, {
            var ref = WhiteNoise.ar(0.2);
            var target = DelayN.ar(ref, 0.01, 5 / sr);
            var sigs = NLMS.ar(ref, target, mu: 0.2, eps: 0.0001);
            RecordBuf.ar(sigs[0], bufY, loop: 0);
            RecordBuf.ar(sigs[1], bufE, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureNLMSConvergence);
        (dur + 0.1).wait;

        bufE.loadToFloatArray(action: { |dataE|
            var earlyWindow = dataE.copyRange(0, 500);
            var lateWindow = dataE.copyRange(numSamples - 1000, numSamples - 1);
            var earlyRMS = (earlyWindow.squared.sum / earlyWindow.size).sqrt;
            var lateRMS = (lateWindow.squared.sum / lateWindow.size).sqrt;
            var isConverged = lateRMS < (earlyRMS * 0.3);

            assertTest.value("NLMS error decreases substantially through real-time adaptation", isConverged, "early RMS: " ++ earlyRMS.round(0.001) ++ " -> late RMS: " ++ lateRMS.round(0.001));
        });
        s.sync;
        bufY.free;
        bufE.free;
    }.value;

    // --- Test 3: Freezing with mu = 0 ---
    "--- Test 3: Freezing with mu = 0 ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.3;
        var numSamples = (sr * dur).asInteger;
        var buf = Buffer.alloc(s, numSamples, 1);
        s.sync;

        SynthDef(\measureNLMSFrozen, {
            var ref = WhiteNoise.ar(0.1);
            var des = SinOsc.ar(440) * 0.1;
            var sigs = NLMS.ar(ref, des, mu: 0.0);
            RecordBuf.ar(sigs[0], buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureNLMSFrozen);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var maxAmp = data.abs.maxItem;
            assertTest.value("With mu = 0, initial unadapted weights stay zero (output = 0)", maxAmp < 1e-6, "peak: " ++ maxAmp);
        });
        s.sync;
        buf.free;
    }.value;

    // --- Test 4: Silence and Division-by-Zero Protection ---
    "--- Test 4: Silence and Division-by-Zero Protection ---".postln;
    {
        var sr = s.sampleRate;
        var dur = 0.2;
        var numSamples = (sr * dur).asInteger;
        var buf = Buffer.alloc(s, numSamples, 1);
        s.sync;

        SynthDef(\measureNLMSSilence, {
            var ref = DC.ar(0);
            var des = DC.ar(0);
            var sigs = NLMS.ar(ref, des, mu: 0.5, eps: 1e-5);
            RecordBuf.ar(sigs[1], buf, loop: 0, doneAction: 2);
        }).send(s);
        s.sync;

        Synth(\measureNLMSSilence);
        (dur + 0.1).wait;

        buf.loadToFloatArray(action: { |data|
            var isFinite = data.every({ |v| v.isNaN.not && (v.abs < 100.0) });
            assertTest.value("NLMS maintains strict stability during silence without NaN or Inf", isFinite);
        });
        s.sync;
        buf.free;
    }.value;

    "\n--------------------------------------------------".postln;
    ("Results: " ++ passCount ++ " / " ++ testCount ++ " tests passed.").postln;
    "--------------------------------------------------\n".postln;

    if (passCount == testCount) {
        "ALL NLMS TESTS PASSED.".postln;
        0.exit;
    } {
        "SOME TESTS FAILED.".postln;
        1.exit;
    };
});
