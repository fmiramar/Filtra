// =====================================================================
// MS20_Audition_GUI.scd: Interactive Visual Audition Studio
// Real-time GUI with oscilloscope and spectrum analyzer for:
// - MS20SK (Linear Sallen-Key Reference)
// - MS20TPT (Zero-Delay Topology-Preserving Transform)
// - MS20Diode (Early Korg-35 Forward Diode Limiter)
// - MS20OTA (Later KLM-307 Dual OTA Feedback Limiter)
// - MS20Circuit (Discrete BJT Reverse-Saturation MNA Circuit)
// Supports optional 2x Polyphase Half-Band Oversampling
// =====================================================================

s.waitForBoot({
    var win, scope, freqScope, synth, bus;
    var modelMenu, modeMenu, sourceMenu;
    var lpFreqSlider, lpResSlider, driveSlider;
    var hpFreqSlider, hpResSlider;
    var fmFreqSlider, fmDepthSlider, volSlider;
    var lpFreqBox, lpResBox, driveBox, hpFreqBox, hpResBox, fmFreqBox, fmDepthBox, volBox;
    var muteBtn, osBtn;

    bus = Bus.audio(s, 2);

    // Audio Engine SynthDef
    SynthDef(\ms20_studio, {
        |out = 0,
         model = 4, mode = 0, source = 0, oversample = 0,
         lpFreq = 1200, lpRes = 0.4, drive = 1.0,
         hpFreq = 150, hpRes = 0.3,
         fmFreq = 0.0, fmDepth = 0.0,
         amp = 0.2, mute = 0|

        var src, sig, fmMod, effLpFreq;

        // Source generator
        src = Select.ar(source, [
            Saw.ar(110) * 0.5,
            Pulse.ar(110, 0.5) * 0.4,
            PinkNoise.ar(0.3),
            (Saw.ar(55) + Saw.ar(55.2) + Pulse.ar(27.5, 0.5) * 0.5) * 0.3
        ]);

        // Audio-rate FM Modulator
        fmMod = SinOsc.ar(fmFreq) * fmDepth;
        effLpFreq = (lpFreq + fmMod).clip(20.0, 18000.0);

        // Filter processing
        sig = Select.ar(mode, [
            // Mode 0: Low-Pass
            Select.ar(model, [
                MS20SK.ar(src, effLpFreq, lpRes, 0),
                MS20TPT.ar(src, effLpFreq, lpRes, 0),
                MS20Diode.ar(src, effLpFreq, lpRes, drive, 0, oversample),
                MS20OTA.ar(src, effLpFreq, lpRes, drive, 0, oversample),
                MS20Circuit.ar(src, effLpFreq, lpRes, drive, 0, oversample)
            ]),
            // Mode 1: Authentic MS-20 High-Pass (6 dB/oct)
            Select.ar(model, [
                MS20SK.ar(src, effLpFreq, lpRes, 1),
                MS20TPT.ar(src, effLpFreq, lpRes, 1),
                MS20Diode.ar(src, effLpFreq, lpRes, drive, 1, oversample),
                MS20OTA.ar(src, effLpFreq, lpRes, drive, 1, oversample),
                MS20Circuit.ar(src, effLpFreq, lpRes, drive, 1, oversample)
            ]),
            // Mode 2: Serial Dual MS-20 Filter (HPF -> LPF)
            Select.ar(model, [
                MS20SK.ar(MS20SK.ar(src, hpFreq, hpRes, 1), effLpFreq, lpRes, 0),
                MS20TPT.ar(MS20TPT.ar(src, hpFreq, hpRes, 1), effLpFreq, lpRes, 0),
                MS20Diode.ar(MS20Diode.ar(src, hpFreq, hpRes, drive, 1, oversample), effLpFreq, lpRes, drive, 0, oversample),
                MS20OTA.ar(MS20OTA.ar(src, hpFreq, hpRes, drive, 1, oversample), effLpFreq, lpRes, drive, 0, oversample),
                MS20Circuit.ar(MS20Circuit.ar(src, hpFreq, hpRes, drive, 1, oversample), effLpFreq, lpRes, drive, 0, oversample)
            ])
        ]);

        sig = sig * (1.0 - mute) * amp;
        Out.ar(out, sig ! 2);
    }).add;

    s.sync;

    synth = Synth(\ms20_studio, [\out, bus.index]);

    // Forward bus to hardware speakers
    { Out.ar(0, In.ar(bus.index, 2)); }.play(s);

    // GUI Layout
    defer {
        win = Window("Korg MS-20 Filter Family Studio", Rect(100, 100, 840, 680));
        win.view.background = Color(0.12, 0.12, 0.14);

        // Visualizers
        freqScope = FreqScopeView(win, Rect(20, 20, 400, 220), s);
        freqScope.active_(true);
        freqScope.freqMode_(1); // Logarithmic frequency scale
        freqScope.inBus_(bus.index);

        scope = ScopeView(win, Rect(430, 20, 390, 220));
        scope.server = s;
        scope.bufnum = 0;
        scope.start;

        // Top Control Bar: Model, Mode, Source
        StaticText(win, Rect(20, 260, 80, 20)).string_("Model:").stringColor_(Color.white);
        modelMenu = PopUpMenu(win, Rect(75, 258, 195, 24))
            .items_(["MS20SK (Linear)", "MS20TPT (ZDF)", "MS20Diode (Diode)", "MS20OTA (OTA)", "MS20Circuit (BJT MNA)"])
            .value_(4)
            .action_({ |menu| synth.set(\model, menu.value); });

        StaticText(win, Rect(280, 260, 80, 20)).string_("Mode:").stringColor_(Color.white);
        modeMenu = PopUpMenu(win, Rect(330, 258, 200, 24))
            .items_(["Low-Pass (12 dB/oct)", "MS-20 High-Pass (6 dB/oct)", "Serial Dual (HP -> LP)"])
            .value_(0)
            .action_({ |menu| synth.set(\mode, menu.value); });

        StaticText(win, Rect(550, 260, 80, 20)).string_("Source:").stringColor_(Color.white);
        sourceMenu = PopUpMenu(win, Rect(610, 258, 200, 24))
            .items_(["Sawtooth (110 Hz)", "Square / Pulse", "Pink Noise", "Dual VCO + Sub Bass"])
            .value_(0)
            .action_({ |menu| synth.set(\source, menu.value); });

        // Sliders Helper
        // 1. LP Cutoff
        StaticText(win, Rect(20, 305, 120, 20)).string_("LP Cutoff (Hz):").stringColor_(Color.white);
        lpFreqSlider = Slider(win, Rect(140, 305, 580, 20))
            .value_(\exp.asSpec.map(1200 / 20000))
            .action_({ |sl|
                var val = ControlSpec(20.0, 18000.0, \exp).map(sl.value);
                lpFreqBox.value = val.round(0.1);
                synth.set(\lpFreq, val);
            });
        lpFreqBox = NumberBox(win, Rect(730, 305, 80, 20)).value_(1200);

        // 2. LP Resonance
        StaticText(win, Rect(20, 340, 120, 20)).string_("LP Resonance:").stringColor_(Color.white);
        lpResSlider = Slider(win, Rect(140, 340, 580, 20))
            .value_(0.4)
            .action_({ |sl|
                lpResBox.value = sl.value.round(0.01);
                synth.set(\lpRes, sl.value);
            });
        lpResBox = NumberBox(win, Rect(730, 340, 80, 20)).value_(0.4);

        // 3. Drive / Saturation
        StaticText(win, Rect(20, 375, 120, 20)).string_("Drive / Saturation:").stringColor_(Color.white);
        driveSlider = Slider(win, Rect(140, 375, 580, 20))
            .value_(0.2) // maps 0.1 to 5.0
            .action_({ |sl|
                var val = ControlSpec(0.1, 5.0, \lin).map(sl.value);
                driveBox.value = val.round(0.01);
                synth.set(\drive, val);
            });
        driveBox = NumberBox(win, Rect(730, 375, 80, 20)).value_(1.0);

        // 4. HP Cutoff (for Dual Serial Mode)
        StaticText(win, Rect(20, 410, 120, 20)).string_("HP Cutoff (Hz):").stringColor_(Color.white);
        hpFreqSlider = Slider(win, Rect(140, 410, 580, 20))
            .value_(\exp.asSpec.map(150 / 20000))
            .action_({ |sl|
                var val = ControlSpec(20.0, 18000.0, \exp).map(sl.value);
                hpFreqBox.value = val.round(0.1);
                synth.set(\hpFreq, val);
            });
        hpFreqBox = NumberBox(win, Rect(730, 410, 80, 20)).value_(150);

        // 5. HP Resonance
        StaticText(win, Rect(20, 445, 120, 20)).string_("HP Resonance:").stringColor_(Color.white);
        hpResSlider = Slider(win, Rect(140, 445, 580, 20))
            .value_(0.3)
            .action_({ |sl|
                hpResBox.value = sl.value.round(0.01);
                synth.set(\hpRes, sl.value);
            });
        hpResBox = NumberBox(win, Rect(730, 445, 80, 20)).value_(0.3);

        // 6. FM Frequency
        StaticText(win, Rect(20, 490, 120, 20)).string_("FM Rate (Hz):").stringColor_(Color.white);
        fmFreqSlider = Slider(win, Rect(140, 490, 580, 20))
            .value_(0.0)
            .action_({ |sl|
                var val = ControlSpec(0.0, 1000.0, \lin).map(sl.value);
                fmFreqBox.value = val.round(0.1);
                synth.set(\fmFreq, val);
            });
        fmFreqBox = NumberBox(win, Rect(730, 490, 80, 20)).value_(0.0);

        // 7. FM Depth
        StaticText(win, Rect(20, 525, 120, 20)).string_("FM Depth (Hz):").stringColor_(Color.white);
        fmDepthSlider = Slider(win, Rect(140, 525, 580, 20))
            .value_(0.0)
            .action_({ |sl|
                var val = ControlSpec(0.0, 5000.0, \lin).map(sl.value);
                fmDepthBox.value = val.round(1.0);
                synth.set(\fmDepth, val);
            });
        fmDepthBox = NumberBox(win, Rect(730, 525, 80, 20)).value_(0.0);

        // 8. Output Volume, Mute & Oversampling
        StaticText(win, Rect(20, 570, 120, 20)).string_("Master Volume:").stringColor_(Color.white);
        volSlider = Slider(win, Rect(140, 570, 260, 20))
            .value_(0.5)
            .action_({ |sl|
                var val = sl.value * 0.4;
                volBox.value = (sl.value * 100).round(1);
                synth.set(\amp, val);
            });
        volBox = NumberBox(win, Rect(410, 570, 45, 20)).value_(50);

        // Oversampling Button
        osBtn = Button(win, Rect(470, 565, 200, 30))
            .states_([
                ["Oversampling: 1x (Fast)", Color.white, Color(0.25, 0.25, 0.3)],
                ["Oversampling: 2x (Hi-Fi)", Color.black, Color(0.2, 0.85, 0.85)]
            ])
            .value_(0)
            .action_({ |btn| synth.set(\oversample, btn.value); });

        muteBtn = Button(win, Rect(685, 565, 125, 30))
            .states_([["MUTE", Color.white, Color.red(0.6)], ["UNMUTE", Color.black, Color.green(0.6)]])
            .action_({ |btn| synth.set(\mute, btn.value); });

        // Clean cleanup on window close
        win.onClose_({
            synth.free;
            bus.free;
            freqScope.kill;
        });

        win.front;
    };
});
