// =====================================================================
// MS-20 Filters Test Suite: 2x Polyphase Half-Band Oversampling
// Tests MS20Diode, MS20Circuit, and MS20OTA under 1x vs 2x oversampling
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
    "  MS-20 Filters: 2x Oversampling Test Suite       ".postln;
    "==================================================\n".postln;

    // -------------------------------------------------------------
    // Test 1: MS20Diode 1x vs 2x Basic Stability and Bounded Output
    // -------------------------------------------------------------
    "--- Test 1: MS20Diode 1x vs 2x Stability ---".postln;
    {
        var buf1x = Buffer.alloc(s, numSamples, 1);
        var buf2x = Buffer.alloc(s, numSamples, 1);
        var data1x, data2x;
        var max1x, max2x;

        s.sync;

        {
            var sig = Saw.ar(440) * 0.8;
            var out = MS20Diode.ar(sig, freq: 2000, res: 0.6, drive: 4.0, mode: 0, oversample: 0);
            RecordBuf.ar(out, buf1x, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;

        {
            var sig = Saw.ar(440) * 0.8;
            var out = MS20Diode.ar(sig, freq: 2000, res: 0.6, drive: 4.0, mode: 0, oversample: 1);
            RecordBuf.ar(out, buf2x, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;

        buf1x.loadToFloatArray(action: { |arr| data1x = arr; });
        buf2x.loadToFloatArray(action: { |arr| data2x = arr; });
        s.sync;

        assert.(data1x.every({ |x| x.isNaN.not && (x.abs < 100.0) }), "MS20Diode 1x produces valid floats (no NaN/Inf)");
        assert.(data2x.every({ |x| x.isNaN.not && (x.abs < 100.0) }), "MS20Diode 2x produces valid floats (no NaN/Inf)");

        max1x = data1x.abs.maxItem;
        max2x = data2x.abs.maxItem;
        ("  MS20Diode peak 1x: " ++ max1x.round(0.001) ++ ", peak 2x: " ++ max2x.round(0.001)).postln;
        assert.(max2x > 0.1 && max2x < 5.0, "MS20Diode 2x output bounded and energetic");

        buf1x.free;
        buf2x.free;
    }.value;

    // -------------------------------------------------------------
    // Test 2: MS20Circuit 1x vs 2x Stability & BJT Harmonics
    // -------------------------------------------------------------
    "--- Test 2: MS20Circuit 1x vs 2x Stability & BJT Harmonics ---".postln;
    {
        var buf1x = Buffer.alloc(s, numSamples, 1);
        var buf2x = Buffer.alloc(s, numSamples, 1);
        var data1x, data2x;
        var max1x, max2x;

        s.sync;

        {
            var sig = SinOsc.ar(200) * 0.8;
            var out = MS20Circuit.ar(sig, freq: 3000, res: 0.5, drive: 3.0, mode: 0, oversample: 0);
            RecordBuf.ar(out, buf1x, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;

        {
            var sig = SinOsc.ar(200) * 0.8;
            var out = MS20Circuit.ar(sig, freq: 3000, res: 0.5, drive: 3.0, mode: 0, oversample: 1);
            RecordBuf.ar(out, buf2x, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;

        buf1x.loadToFloatArray(action: { |arr| data1x = arr; });
        buf2x.loadToFloatArray(action: { |arr| data2x = arr; });
        s.sync;

        assert.(data1x.every({ |x| x.isNaN.not && (x.abs < 100.0) }), "MS20Circuit 1x produces valid floats (no NaN/Inf)");
        assert.(data2x.every({ |x| x.isNaN.not && (x.abs < 100.0) }), "MS20Circuit 2x produces valid floats (no NaN/Inf)");

        max1x = data1x.abs.maxItem;
        max2x = data2x.abs.maxItem;
        ("  MS20Circuit peak 1x: " ++ max1x.round(0.001) ++ ", peak 2x: " ++ max2x.round(0.001)).postln;
        assert.(max2x > 0.1 && max2x < 5.0, "MS20Circuit 2x output bounded and energetic");

        buf1x.free;
        buf2x.free;
    }.value;

    // -------------------------------------------------------------
    // Test 3: MS20OTA 1x vs 2x Stability
    // -------------------------------------------------------------
    "--- Test 3: MS20OTA 1x vs 2x Stability ---".postln;
    {
        var buf1x = Buffer.alloc(s, numSamples, 1);
        var buf2x = Buffer.alloc(s, numSamples, 1);
        var data1x, data2x;
        var max1x, max2x;

        s.sync;

        {
            var sig = Saw.ar(440) * 0.8;
            var out = MS20OTA.ar(sig, freq: 2500, res: 0.7, drive: 2.5, mode: 0, oversample: 0);
            RecordBuf.ar(out, buf1x, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;

        {
            var sig = Saw.ar(440) * 0.8;
            var out = MS20OTA.ar(sig, freq: 2500, res: 0.7, drive: 2.5, mode: 0, oversample: 1);
            RecordBuf.ar(out, buf2x, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;

        buf1x.loadToFloatArray(action: { |arr| data1x = arr; });
        buf2x.loadToFloatArray(action: { |arr| data2x = arr; });
        s.sync;

        assert.(data1x.every({ |x| x.isNaN.not && (x.abs < 100.0) }), "MS20OTA 1x produces valid floats (no NaN/Inf)");
        assert.(data2x.every({ |x| x.isNaN.not && (x.abs < 100.0) }), "MS20OTA 2x produces valid floats (no NaN/Inf)");

        max1x = data1x.abs.maxItem;
        max2x = data2x.abs.maxItem;
        ("  MS20OTA peak 1x: " ++ max1x.round(0.001) ++ ", peak 2x: " ++ max2x.round(0.001)).postln;
        assert.(max2x > 0.1 && max2x < 5.0, "MS20OTA 2x output bounded and energetic");

        buf1x.free;
        buf2x.free;
    }.value;

    // -------------------------------------------------------------
    // Test 4: Audio-Rate FM under 2x Oversampling
    // -------------------------------------------------------------
    "--- Test 4: Audio-Rate FM under 2x Oversampling ---".postln;
    {
        var buf = Buffer.alloc(s, numSamples, 1);
        var data;

        s.sync;

        {
            var sig = Saw.ar(110) * 0.5;
            var fm = SinOsc.ar(250) * 800 + 1500;
            var out = MS20Diode.ar(sig, freq: fm, res: 0.5, drive: 2.0, mode: 0, oversample: 1);
            RecordBuf.ar(out, buf, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;

        buf.loadToFloatArray(action: { |arr| data = arr; });
        s.sync;

        assert.(data.every({ |x| x.isNaN.not && (x.abs < 100.0) }), "MS20Diode 2x with audio-rate FM produces valid floats");
        assert.(data.abs.maxItem > 0.1, "MS20Diode 2x with audio-rate FM has non-zero amplitude");

        buf.free;
    }.value;

    // -------------------------------------------------------------
    // Test 5: Aliasing Reduction Quantification (High-Drive Sine)
    // Input: 3500 Hz sine, drive = 6.0
    // At 44.1 kHz, 9th harmonic is 31.5 kHz -> aliases to 12.6 kHz in 1x mode.
    // 2x oversampling suppresses this aliased energy!
    // -------------------------------------------------------------
    "--- Test 5: Aliasing Reduction Quantification ---".postln;
    {
        var buf1x = Buffer.alloc(s, numSamples, 1);
        var buf2x = Buffer.alloc(s, numSamples, 1);
        var data1x, data2x;
        var pwr1x_12k = 0.0, pwr2x_12k = 0.0;
        var nTail = 8192;
        var tail1x, tail2x;
        var testFreq = 12600.0;
        var k_bin = (testFreq * nTail / 44100.0).round.asInteger;
        var re1 = 0.0, im1 = 0.0, re2 = 0.0, im2 = 0.0;
        var attenDb;

        s.sync;

        {
            var sig = SinOsc.ar(3500) * 1.5;
            var out = MS20Diode.ar(sig, freq: 5000, res: 0.5, drive: 6.0, mode: 0, oversample: 0);
            RecordBuf.ar(out, buf1x, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;

        {
            var sig = SinOsc.ar(3500) * 1.5;
            var out = MS20Diode.ar(sig, freq: 5000, res: 0.5, drive: 6.0, mode: 0, oversample: 1);
            RecordBuf.ar(out, buf2x, loop: 0, doneAction: 2);
            Silent.ar;
        }.play;

        dur.wait;

        buf1x.loadToFloatArray(action: { |arr| data1x = arr; });
        buf2x.loadToFloatArray(action: { |arr| data2x = arr; });
        s.sync;

        tail1x = data1x.copyRange(data1x.size - nTail, data1x.size - 1);
        tail2x = data2x.copyRange(data2x.size - nTail, data2x.size - 1);

        // Compute single DFT bin power at 12600 Hz (the aliased 9th harmonic)
        nTail.do({ |n|
            var angle = 2.0 * pi * k_bin * n / nTail;
            var w = 0.5 * (1.0 - cos(2.0 * pi * n / nTail)); // Hann window
            var s1 = tail1x[n] * w;
            var s2 = tail2x[n] * w;
            re1 = re1 + (s1 * cos(angle));
            im1 = im1 - (s1 * sin(angle));
            re2 = re2 + (s2 * cos(angle));
            im2 = im2 - (s2 * sin(angle));
        });

        pwr1x_12k = (re1.squared + im1.squared) / nTail;
        pwr2x_12k = (re2.squared + im2.squared) / nTail;

        attenDb = 10.0 * log10((pwr1x_12k + 1e-12) / (pwr2x_12k + 1e-12));
        ("  Aliased 9th harmonic (12.6 kHz) power 1x: " ++ pwr1x_12k.asString).postln;
        ("  Aliased 9th harmonic (12.6 kHz) power 2x: " ++ pwr2x_12k.asString).postln;
        ("  Aliasing suppression in 2x mode: " ++ attenDb.round(0.1) ++ " dB").postln;

        assert.(attenDb > 30.0, "2x oversampling suppresses foldover aliasing by > 30 dB (measured " ++ attenDb.round(0.1) ++ " dB)");

        buf1x.free;
        buf2x.free;
    }.value;

    "\n--------------------------------------------------".postln;
    ("Results: " ++ passCount ++ " / " ++ testCount ++ " tests passed.").postln;
    "--------------------------------------------------\n".postln;

    if (passCount == testCount) {
        "ALL 2X OVERSAMPLING TESTS PASSED.".postln;
        0.exit;
    } {
        "SOME TESTS FAILED.".postln;
        1.exit;
    };
});
