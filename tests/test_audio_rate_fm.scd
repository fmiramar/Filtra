// =====================================================================
// test_audio_rate_fm.scd: Audio-Rate Frequency Modulation (FM) Verification
// Tests sample-accurate audio-rate (.ar) cutoff modulation for:
// MS20SK, MS20TPT, MS20Diode, and MS20OTA in both LP and HP modes.
// =====================================================================

var s = Server.default;
var numErrors = 0;

s.options.numOutputBusChannels = 2;
s.options.numInputBusChannels = 0;

s.waitForBoot({
    Routine({
        var testFMModel = { |modelName, filterFunc|
            var bus = Bus.control(s, 2);
            var synth, rmsVal = 0.0, maxVal = 0.0, sSem = Semaphore(0);

            ("--- Testing Audio-Rate FM on " ++ modelName ++ " ---").postln;

            synth = {
                // Audio carrier: Sawtooth wave at 110 Hz
                var src = Saw.ar(110);
                // Audio modulator: Sinusoid at 220 Hz modulating cutoff between 200 Hz and 6000 Hz
                var mod = SinOsc.ar(220).range(200.0, 6000.0);
                var sig = filterFunc.value(src, mod);
                var rms = RunningSum.ar(sig.squared, 2048).sqrt / sqrt(2048);
                var peak = RunningMax.ar(sig.abs, Impulse.kr(20));
                Out.kr(bus, [A2K.kr(rms), A2K.kr(peak)]);
            }.play(s);

            0.3.wait;
            bus.get({ |vals|
                rmsVal = vals[0];
                maxVal = vals[1];
                sSem.signal;
            });
            sSem.wait;
            synth.free;
            bus.free;

            (modelName ++ " Audio-Rate FM Output RMS: " ++ rmsVal.round(0.001) ++ ", Peak: " ++ maxVal.round(0.001)).postln;

            if (rmsVal.isNaN or: { maxVal.isNaN } or: { rmsVal <= 0.0 } or: { maxVal > 15.0 }) {
                ("FAIL: " ++ modelName ++ " audio-rate FM stability test failed!").postln;
                numErrors = numErrors + 1;
            } {
                ("PASS: " ++ modelName ++ " handles audio-rate FM cleanly and stably.").postln;
            };
        };

        // 1. MS20SK LP audio-rate FM
        testFMModel.value("MS20SK (LP)", { |src, mod|
            MS20SK.ar(src, mod, 0.4, 0)
        });

        // 2. MS20SK HP audio-rate FM
        testFMModel.value("MS20SK (HP)", { |src, mod|
            MS20SK.ar(src, mod, 0.4, 1)
        });

        // 3. MS20TPT LP audio-rate FM
        testFMModel.value("MS20TPT (LP)", { |src, mod|
            MS20TPT.ar(src, mod, 0.4, 0)
        });

        // 4. MS20TPT HP audio-rate FM
        testFMModel.value("MS20TPT (HP)", { |src, mod|
            MS20TPT.ar(src, mod, 0.4, 1)
        });

        // 5. MS20Diode LP audio-rate FM
        testFMModel.value("MS20Diode (LP)", { |src, mod|
            MS20Diode.ar(src, mod, 0.6, 1.5, 0)
        });

        // 6. MS20Diode HP audio-rate FM
        testFMModel.value("MS20Diode (HP)", { |src, mod|
            MS20Diode.ar(src, mod, 0.6, 1.5, 1)
        });

        // 7. MS20OTA LP audio-rate FM
        testFMModel.value("MS20OTA (LP)", { |src, mod|
            MS20OTA.ar(src, mod, 0.6, 1.5, 0)
        });

        // 8. MS20OTA HP audio-rate FM
        testFMModel.value("MS20OTA (HP)", { |src, mod|
            MS20OTA.ar(src, mod, 0.6, 1.5, 1)
        });

        // 9. MS20Circuit LP audio-rate FM
        testFMModel.value("MS20Circuit (LP)", { |src, mod|
            MS20Circuit.ar(src, mod, 0.6, 1.5, 0)
        });

        // 10. MS20Circuit HP audio-rate FM
        testFMModel.value("MS20Circuit (HP)", { |src, mod|
            MS20Circuit.ar(src, mod, 0.6, 1.5, 1)
        });

        // 11. Extreme Filter FM: High frequency carrier & 1 kHz modulator with self-oscillation
        ("--- Testing Extreme FM & High Resonance ---").postln;
        {
            var bus = Bus.control(s, 1);
            var synth, maxPeak = 0.0, sSem = Semaphore(0);

            synth = {
                var src = WhiteNoise.ar(0.1);
                var mod = SinOsc.ar(1200).range(50.0, 10000.0);
                var sig = MS20Diode.ar(src, mod, 0.95, 3.0, 0);
                Out.kr(bus, A2K.kr(RunningMax.ar(sig.abs, Impulse.kr(20))));
            }.play(s);

            0.3.wait;
            bus.get({ |val|
                maxPeak = val;
                sSem.signal;
            });
            sSem.wait;
            synth.free;
            bus.free;

            ("Extreme FM Peak: " ++ maxPeak.round(0.001)).postln;
            if (maxPeak.isNaN or: { maxPeak > 5.0 } or: { maxPeak <= 0.0 }) {
                ("FAIL: Extreme FM unstable!").postln;
                numErrors = numErrors + 1;
            } {
                ("PASS: Extreme FM remains bounded and robust under extreme modulation depth.").postln;
            };
        }.value;

        s.sync;
        ("========================================").postln;
        if (numErrors == 0) {
            ("ALL AUDIO-RATE FM TESTS PASSED!").postln;
            s.quit;
            0.exit;
        } {
            ("TOTAL FAILURES: " ++ numErrors).postln;
            s.quit;
            1.exit;
        };
    }).play;
});
