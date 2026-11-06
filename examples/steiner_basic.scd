// =====================================================================
// steiner_basic.scd: Steiner Basic Audition & Demonstration
// Virtual Analog Model of the Steiner-Parker Multimode Diode VCF
// Reference: Nyle Steiner (1974), Yves Usson (YuSynth 2004)
// =====================================================================

s.waitForBoot({
    "--- 1. Steiner Low-Pass Cutoff Sweep (Sawtooth) ---".postln;
    x = {
        var src = Saw.ar([110, 110.5]) * 0.2;
        var cutoff = SinOsc.kr(0.2).exprange(100, 8000);
        var sig = Steiner.ar(src, freq: cutoff, res: 0.6, mode: 0, drive: 1.0);
        sig * 0.3
    }.play;

    3.wait;
    x.free;

    "--- 2. Steiner Band-Pass Resonance Sweep (Pink Noise) ---".postln;
    x = {
        var src = PinkNoise.ar(0.3 ! 2);
        var cutoff = SinOsc.kr(0.15).exprange(200, 4000);
        var res = Line.kr(0.1, 0.95, 4);
        var sig = Steiner.ar(src, freq: cutoff, res: res, mode: 1, drive: 1.0);
        sig * 0.25
    }.play;

    4.wait;
    x.free;

    "--- 3. Steiner High-Pass Sweep ---".postln;
    x = {
        var src = Saw.ar([55, 55.2]) * 0.2;
        var cutoff = XLine.kr(80, 5000, 3);
        var sig = Steiner.ar(src, freq: cutoff, res: 0.5, mode: 2, drive: 1.0);
        sig * 0.3
    }.play;

    3.wait;
    x.free;

    "--- 4. Steiner Audio-Rate FM Modulation ---".postln;
    x = {
        var carrier = Saw.ar(110) * 0.2;
        var mod = SinOsc.ar(220) * 1200;
        var cutoff = (2000 + mod).clip(50, 15000);
        var sig = Steiner.ar(carrier, freq: cutoff, res: 0.7, mode: 0, drive: 1.0);
        (sig * 0.25) ! 2
    }.play;

    3.wait;
    x.free;

    "--- 5. Steiner Diode-Limited Self-Oscillation Limit Cycle ---".postln;
    x = {
        var trig = Impulse.ar(2) * 0.1;
        var cutoff = SinOsc.kr(0.25).exprange(250, 2000);
        var sig = Steiner.ar(trig, freq: cutoff, res: 0.95, mode: 0, drive: 1.2);
        (sig * 0.2) ! 2
    }.play;

    4.wait;
    x.free;

    "Steiner audition complete.".postln;
});
