// =====================================================================
// test_ms20circuit.scd: Verification of MS20Circuit (Transistor / Circuit Model)
// Tests:
// 1. SynthDef graph compilation and UGen instantiation.
// 2. Small-signal linearity check against linear theoretical target.
// 3. Asymmetric Even-Harmonic Generation (prominent 2nd harmonic 2f from reverse-saturation BJT).
// 4. Frequency response: LP 12 dB/oct and HP 6 dB/oct slopes.
// 5. Autonomous limit-cycle self-oscillation without digital divergence.
// 6. Modulation stability under audio-rate FM and rapid sweeps.
// =====================================================================

var s = Server.default;
var numErrors = 0;

s.options.numOutputBusChannels = 2;
s.options.numInputBusChannels = 0;

s.waitForBoot({
    Routine({
        // 1. Class and SynthDef graph compilation
        ("--- Test 1: Class and SynthDef graph compilation ---").postln;
        try {
            var def = SynthDef(\test_compile, {
                var sig = MS20Circuit.ar(WhiteNoise.ar(0.1), 1000, 0.25, 1.0, 0);
                Out.ar(0, sig);
            });
            ("PASS: SynthDef using MS20Circuit compiled successfully.").postln;
        } { |err|
            ("FAIL: SynthDef compilation failed: " ++ err.errorString).postln;
            numErrors = numErrors + 1;
        };

        // 2. Small-Signal Linearity (20 Hz passband tone)
        ("--- Test 2: Small-Signal Passband Linearity ---").postln;
        {
            var bus = Bus.control(s, 1);
            var synth, maxVal = 0.0, sSem = Semaphore(0);

            synth = {
                var src = SinOsc.ar(20, 0, 1e-4);
                var sig = MS20Circuit.ar(src, 1000, 0.25, 1.0, 0);
                Out.kr(bus, A2K.kr(RunningMax.ar(sig.abs, Impulse.kr(20))));
            }.play(s);

            0.3.wait;
            bus.get({ |val|
                maxVal = val;
                sSem.signal;
            });
            sSem.wait;
            synth.free;
            bus.free;

            ("Circuit Small-Signal 20 Hz Gain: " ++ (maxVal / 1e-4).round(0.001)).postln;
            if (abs((maxVal / 1e-4) - 1.0) < 0.02) {
                ("PASS: MS20Circuit behaves with linear fidelity at small signal levels.").postln;
            } {
                ("FAIL: Small signal linearity outside expected bounds!").postln;
                numErrors = numErrors + 1;
            };
        }.value;

        // 3. Even-Harmonic Generation (2nd harmonic 400 Hz from 200 Hz carrier)
        ("--- Test 3: Asymmetric BJT Even-Harmonic Generation ---").postln;
        {
            var h2Bus = Bus.control(s, 2);
            var synth, h1Rms = 0.0, h2Rms = 0.0, sSem = Semaphore(0);

            synth = {
                // Hot sine input (amplitude 1.5, drive 3.0)
                var src = SinOsc.ar(200, 0, 1.5);
                var sig = MS20Circuit.ar(src, 2500, 0.2, 3.0, 0);
                // Bandpass filters to isolate fundamental (200 Hz) and 2nd harmonic (400 Hz)
                var h1 = BPF.ar(sig, 200, 0.1);
                var h2 = BPF.ar(sig, 400, 0.1);
                var rms1 = RunningSum.ar(h1.squared, 2048).sqrt / sqrt(2048);
                var rms2 = RunningSum.ar(h2.squared, 2048).sqrt / sqrt(2048);
                Out.kr(h2Bus, [A2K.kr(rms1), A2K.kr(rms2)]);
            }.play(s);

            0.3.wait;
            h2Bus.get({ |vals|
                h1Rms = vals[0];
                h2Rms = vals[1];
                sSem.signal;
            });
            sSem.wait;
            synth.free;
            h2Bus.free;

            ("Fundamental (200 Hz) RMS: " ++ h1Rms.round(0.001) ++ ", Second Harmonic (400 Hz) RMS: " ++ h2Rms.round(0.001)).postln;
            ("Second Harmonic Ratio: " ++ (h2Rms / h1Rms * 100).round(0.1) ++ "%").postln;

            if (h2Rms / h1Rms > 0.02) {
                ("PASS: MS20Circuit generates authentic asymmetric BJT 2nd harmonic (>2%).").postln;
            } {
                ("FAIL: Expected significant 2nd harmonic generation from reverse-saturated BJT!").postln;
                numErrors = numErrors + 1;
            };
        }.value;

        // 4. Slope Verification (LP 12 dB/oct and HP 6 dB/oct)
        ("--- Test 4: LP and HP Asymptotic Slope Verification ---").postln;
        {
            var bus = Bus.control(s, 2);
            var synth, g1 = 0.0, g2 = 0.0, sSem = Semaphore(0);

            // LP Slope check (2000 to 4000 Hz with fc=500 Hz)
            synth = {
                var s1 = SinOsc.ar(2000, 0, 0.01);
                var s2 = SinOsc.ar(4000, 0, 0.01);
                var lp1 = MS20Circuit.ar(s1, 500, 0.1, 1.0, 0);
                var lp2 = MS20Circuit.ar(s2, 500, 0.1, 1.0, 0);
                var m1 = RunningSum.ar(lp1.squared, 2048).sqrt / sqrt(2048) / 0.00707;
                var m2 = RunningSum.ar(lp2.squared, 2048).sqrt / sqrt(2048) / 0.00707;
                Out.kr(bus, [A2K.kr(m1), A2K.kr(m2)]);
            }.play(s);

            0.3.wait;
            bus.get({ |vals|
                g1 = vals[0];
                g2 = vals[1];
                sSem.signal;
            });
            sSem.wait;
            synth.free;
            bus.free;

            {
                var lpSlope = 20.0 * log10(g2 / g1);
                ("Circuit LP Stopband Slope (2000 to 4000 Hz): " ++ lpSlope.round(0.1) ++ " dB/oct").postln;
                if (lpSlope < -10.5 and: { lpSlope > -13.5 }) {
                    ("PASS: MS20Circuit LP exhibits expected ~12 dB/octave stopband slope.").postln;
                } {
                    ("FAIL: Unexpected LP slope!").postln;
                    numErrors = numErrors + 1;
                };
            }.value;
        }.value;

        // HP Slope check (100 to 200 Hz with fc=3000 Hz)
        {
            var bus = Bus.control(s, 2);
            var synth, g1 = 0.0, g2 = 0.0, sSem = Semaphore(0);

            synth = {
                var s1 = SinOsc.ar(100, 0, 0.01);
                var s2 = SinOsc.ar(200, 0, 0.01);
                var hp1 = MS20Circuit.ar(s1, 3000, 0.1, 1.0, 1);
                var hp2 = MS20Circuit.ar(s2, 3000, 0.1, 1.0, 1);
                var m1 = RunningSum.ar(hp1.squared, 2048).sqrt / sqrt(2048) / 0.00707;
                var m2 = RunningSum.ar(hp2.squared, 2048).sqrt / sqrt(2048) / 0.00707;
                Out.kr(bus, [A2K.kr(m1), A2K.kr(m2)]);
            }.play(s);

            0.3.wait;
            bus.get({ |vals|
                g1 = vals[0];
                g2 = vals[1];
                sSem.signal;
            });
            sSem.wait;
            synth.free;
            bus.free;

            {
                var hpSlope = 20.0 * log10(g2 / g1);
                ("Circuit HP Low-Frequency Slope (100 to 200 Hz): " ++ hpSlope.round(0.1) ++ " dB/oct").postln;
                if (hpSlope > 5.0 and: { hpSlope < 6.8 }) {
                    ("PASS: MS20Circuit HP exhibits authentic MS-20 ~6 dB/octave slope.").postln;
                } {
                    ("FAIL: Unexpected HP slope!").postln;
                    numErrors = numErrors + 1;
                };
            }.value;
        }.value;

        // 5. Autonomous Limit-Cycle Self-Oscillation
        ("--- Test 5: Autonomous Limit-Cycle Self-Oscillation ---").postln;
        {
            var bus = Bus.control(s, 1);
            var synth, oscRms = 0.0, sSem = Semaphore(0);

            synth = {
                // 1-sample kick at t=0, then absolute silence
                var src = Impulse.ar(0) * 0.01;
                var sig = MS20Circuit.ar(src, 800, 0.9, 1.5, 0);
                var rms = RunningSum.ar(sig.squared, 2048).sqrt / sqrt(2048);
                Out.kr(bus, A2K.kr(rms));
            }.play(s);

            0.4.wait;
            bus.get({ |val|
                oscRms = val;
                sSem.signal;
            });
            sSem.wait;
            synth.free;
            bus.free;

            ("Circuit Self-Oscillation Limit-Cycle RMS: " ++ oscRms.round(0.001)).postln;
            if (oscRms > 0.2 and: { oscRms < 1.0 }) {
                ("PASS: MS20Circuit self-oscillates stably into a bounded limit cycle.").postln;
            } {
                ("FAIL: Circuit self-oscillation failed or diverged!").postln;
                numErrors = numErrors + 1;
            };
        }.value;

        // 6. Audio-rate FM Modulation Stability
        ("--- Test 6: Audio-Rate FM Modulation Stability ---").postln;
        {
            var bus = Bus.control(s, 1);
            var synth, peakVal = 0.0, sSem = Semaphore(0);

            synth = {
                var src = Saw.ar(110);
                var mod = SinOsc.ar(300).range(100.0, 7000.0);
                var sig = MS20Circuit.ar(src, mod, 0.7, 2.0, 0);
                Out.kr(bus, A2K.kr(RunningMax.ar(sig.abs, Impulse.kr(20))));
            }.play(s);

            0.3.wait;
            bus.get({ |val|
                peakVal = val;
                sSem.signal;
            });
            sSem.wait;
            synth.free;
            bus.free;

            ("Circuit Audio-Rate FM Peak: " ++ peakVal.round(0.001)).postln;
            if (peakVal.isNaN or: { peakVal <= 0.0 } or: { peakVal > 10.0 }) {
                ("FAIL: Circuit audio-rate FM failed!").postln;
                numErrors = numErrors + 1;
            } {
                ("PASS: MS20Circuit handles audio-rate FM stably and cleanly.").postln;
            };
        }.value;

        s.sync;
        ("========================================").postln;
        if (numErrors == 0) {
            ("ALL MS20Circuit VERIFICATION TESTS PASSED!").postln;
            s.quit;
            0.exit;
        } {
            ("TOTAL FAILURES: " ++ numErrors).postln;
            s.quit;
            1.exit;
        };
    }).play;
});
