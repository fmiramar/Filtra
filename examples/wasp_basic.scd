// =====================================================================
// wasp_basic.scd: FSWasp Basic Audition & Demonstration (Stage W1 & W2)
// Virtual Analog Model of the EDP Wasp State-Variable Filter (DAFx 2022)
// Reference: Köper, Holters, Esqueda, Parker (DAFx 2022)
// =====================================================================

s.waitForBoot({
    "--- 1. FSWasp Low-Pass Cutoff Sweep (Sawtooth) ---".postln;
    x = {
        var src = Saw.ar([110, 110.5]) * 0.2;
        var cutoff = SinOsc.kr(0.2).exprange(100, 8000);
        // Mode 0 = Low-Pass (12 dB/octave)
        var sig = FSWasp.ar(src, freq: cutoff, res: 0.6, drive: 1.0, mode: 0);
        sig * 0.3
    }.play;

    3.wait;
    x.free;

    "--- 2. FSWasp Band-Pass Resonance Sweep (Pink Noise) ---".postln;
    x = {
        var src = PinkNoise.ar(0.3 ! 2);
        var cutoff = SinOsc.kr(0.15).exprange(200, 4000);
        var res = Line.kr(0.1, 0.95, 4);
        // Mode 1 = Band-Pass
        var sig = FSWasp.ar(src, freq: cutoff, res: res, drive: 1.0, mode: 1);
        sig * 0.25
    }.play;

    4.wait;
    x.free;

    "--- 3. FSWasp High-Pass Sweep ---".postln;
    x = {
        var src = Saw.ar([55, 55.2]) * 0.2;
        var cutoff = XLine.kr(80, 5000, 3);
        // Mode 2 = High-Pass
        var sig = FSWasp.ar(src, freq: cutoff, res: 0.5, drive: 1.0, mode: 2);
        sig * 0.3
    }.play;

    3.wait;
    x.free;

    "--- 4. FSWasp Audio-Rate FM Modulation ---".postln;
    x = {
        var carrier = Saw.ar(110) * 0.2;
        var mod = SinOsc.ar(220) * 1200;
        var cutoff = (2000 + mod).clip(50, 15000);
        var sig = FSWasp.ar(carrier, freq: cutoff, res: 0.7, drive: 1.0, mode: 0);
        (sig * 0.25) ! 2
    }.play;

    3.wait;
    x.free;

    "--- 5. FSWasp Stage W2 Nonlinear Drive Sweep (OTA & CMOS Saturation) ---".postln;
    x = {
        var src = Saw.ar([110, 110.2]) * 0.3;
        var drive = Line.kr(1.0, 5.0, 4);
        var sig = FSWasp.ar(src, freq: 1200, res: 0.75, drive: drive, mode: 0);
        sig * 0.25
    }.play;

    4.wait;
    x.free;

    "FSWasp audition complete.".postln;
});
