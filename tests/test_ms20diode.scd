// MS20Diode Milestone 3 Verification Script

s = Server.default;
s.options.numOutputBusChannels = 2;
s.options.numInputBusChannels = 2;

s.waitForBoot {
    var numErrors = 0;
    var sr = s.sampleRate;
    ("SuperCollider Server booted at sample rate: " ++ sr).postln;

    // 1. Verify Class and SynthDef graph compilation
    ("--- Test 1: Class and SynthDef graph compilation ---").postln;
    try {
        var def = SynthDef(\testMS20Diode_Compilation, {
            var in = WhiteNoise.ar(0.1);
            var lp = MS20Diode.ar(in, 1000, 0.25, 1.0, 0);
            var hp = MS20Diode.ar(lp, 200, 0.25, 1.0, 1);
            Out.ar(0, hp);
        });
        ("PASS: SynthDef using MS20Diode compiled successfully.").postln;
    } { |err|
        ("FAIL: SynthDef compilation failed: " ++ err).postln;
        numErrors = numErrors + 1;
    };

    fork {
        var sem = Semaphore(0);

        // 2. Small-Signal Linearity (MS20Diode vs MS20TPT)
        ("--- Test 2: Small-Signal Linearity (MS20Diode vs MS20TPT) ---").postln;
        {
            var diffBus = Bus.control(s, 1);
            var synth, maxDiff = 0.0, sSem = Semaphore(0);

            synth = {
                // Very small input: 0.005 peak
                var src = SinOsc.ar(440) * 0.005;
                var sigTPT = MS20TPT.ar(src, 1000, 0.5, 0);
                var sigDio = MS20Diode.ar(src, 1000, 0.5 * (2.95 / 4.0), 1.0, 0);
                var diff = (sigTPT - sigDio).abs;
                Out.kr(diffBus, A2K.kr(RunningMax.ar(diff, Impulse.kr(20))));
            }.play(s);

            0.2.wait;
            diffBus.get({ |val|
                maxDiff = val;
                sSem.signal;
            });
            sSem.wait;
            synth.free;
            diffBus.free;

            ("Small-signal peak difference |MS20TPT - MS20Diode|: " ++ maxDiff.asString).postln;
            if (maxDiff < 0.001) {
                ("PASS: MS20Diode behaves near-linearly for small signals.").postln;
            } {
                ("FAIL: Small-signal discrepancy exceeded tolerance!").postln;
                numErrors = numErrors + 1;
            };
        }.value;

        // 3. Harmonic Generation Under Drive
        ("--- Test 3: Harmonic Generation Under High Drive ---").postln;
        {
            var rmsBus = Bus.control(s, 1);
            var synth, rmsVal = 0.0, sSem = Semaphore(0);

            synth = {
                // Hot input into high drive
                var src = SinOsc.ar(200) * 1.5;
                var sigDio = MS20Diode.ar(src, 2000, 0.2, 3.0, 0);
                var rms = RunningSum.ar(sigDio.squared, 2048).sqrt / sqrt(2048);
                Out.kr(rmsBus, A2K.kr(rms));
            }.play(s);

            0.2.wait;
            rmsBus.get({ |val|
                rmsVal = val;
                sSem.signal;
            });
            sSem.wait;
            synth.free;
            rmsBus.free;

            ("Driven Output RMS: " ++ rmsVal.round(0.001) ++ " (bounded and compressed)").postln;
            if (rmsVal > 0.2 and: { rmsVal < 1.0 }) {
                ("PASS: High drive compresses signal stably within diode saturation boundary.").postln;
            } {
                ("FAIL: Driven output level outside expected bounds!").postln;
                numErrors = numErrors + 1;
            };
        }.value;

        // 4. Autonomous Self-Oscillation (Kick-started into Limit Cycle)
        ("--- Test 4: Autonomous Self-Oscillation at High Resonance ---").postln;
        {
            var oscBus = Bus.control(s, 1);
            var synth, oscRms = 0.0, sSem = Semaphore(0);

            synth = {
                // Single initial impulse kicks circuit into self-oscillation, then zero input
                var trigger = Impulse.ar(0) * 0.01;
                var selfOsc = MS20Diode.ar(trigger, freq: 800, res: 0.95, drive: 1.0, mode: 0);
                var rms = RunningSum.ar(selfOsc.squared, 4096).sqrt / sqrt(4096);
                Out.kr(oscBus, A2K.kr(rms));
            }.play(s);

            0.35.wait; // Allow limit cycle to build and stabilize
            oscBus.get({ |val|
                oscRms = val;
                sSem.signal;
            });
            sSem.wait;
            synth.free;
            oscBus.free;

            ("Self-Oscillation Limit-Cycle RMS: " ++ oscRms.round(0.001)).postln;
            if (oscRms > 0.2 and: { oscRms < 0.9 }) {
                ("PASS: MS20Diode self-oscillates cleanly into a stable, bounded limit cycle.").postln;
            } {
                ("FAIL: Self-oscillation failed to produce bounded limit cycle!").postln;
                numErrors = numErrors + 1;
            };
        }.value;

        // 5. Stability under rapid modulation
        ("--- Test 5: Silence, DC, and Modulation Stability ---").postln;
        {
            var testSynth, outBus = Bus.control(s, 1);
            var isNan = 0.0;
            var semMod = Semaphore(0);

            testSynth = {
                var sig = Saw.ar(110) * 0.5;
                var cutoffMod = XLine.kr(50, 15000, 0.1);
                var flt = MS20Diode.ar(sig, cutoffMod, 0.95, 2.0, 0);
                var checkNan = CheckBadValues.ar(flt, post: 0);
                Out.kr(outBus, A2K.kr(checkNan));
            }.play(s);

            0.15.wait;
            outBus.get({ |val|
                isNan = val;
                semMod.signal;
            });
            semMod.wait;
            testSynth.free;
            outBus.free;

            if (isNan == 0) {
                ("PASS: MS20Diode operates cleanly without NaN/Inf during aggressive modulation.").postln;
            } {
                ("FAIL: Bad values detected during modulation!").postln;
                numErrors = numErrors + 1;
            };
        }.value;

        // --- Summary & Exit ---
        0.1.wait;
        ("========================================").postln;
        if (numErrors == 0) {
            ("ALL MILESTONE 3 VERIFICATION TESTS PASSED!").postln;
            0.exit;
        } {
            ("FAILURE: " ++ numErrors ++ " tests failed!").postln;
            1.exit;
        };
    };
};
