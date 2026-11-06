/*
    Filtra - Dispersion Audition & Demonstration
    Dispersive All-Pass Group-Delay Filter (Abel & Smith, DAFx 2006)
*/

s.boot;

(
s.waitForBoot({
    "=================================================".postln;
    "  Filtra: Dispersion Audition Demo              ".postln;
    "=================================================".postln;

    // 1. Audition Impulse Chirp / Dispersion
    "Stage 1: Impulse Dispersion (Laser Chirp / Twang)...".postln;
    x = {
        var trig = Impulse.ar(4);
        var sig = Dispersion.ar(trig, center: 1600, spread: 1.5, q: 5.0);
        sig * 0.4 ! 2;
    }.play;
    3.0.wait;
    x.free;

    // 2. Audition Snare / Rimshot Noise Smear
    "Stage 2: Noise Burst Dispersion (Spring / Plate Smear)...".postln;
    x = {
        var burst = Decay2.ar(Impulse.ar(2), 0.001, 0.03) * WhiteNoise.ar(0.5);
        var sig = Dispersion.ar(burst, center: 2200, spread: 2.0, q: 3.5);
        sig * 0.4 ! 2;
    }.play;
    3.0.wait;
    x.free;

    // 3. Audition Flat Magnitude Preservation on Harmonic Signal
    "Stage 3: Sawtooth Pass-Through (Audible Phase Shift, Flat Magnitude)...".postln;
    x = {
        var src = Saw.ar([110, 110.5]) * 0.25;
        var centerSweep = SinOsc.kr(0.2).exprange(300, 5000);
        var sig = Dispersion.ar(src, center: centerSweep, spread: 1.0, q: 2.0);
        sig * 0.4;
    }.play;
    3.0.wait;
    x.free;

    // 4. Audition Fast Audio-Rate Frequency Modulation
    "Stage 4: Audio-Rate Frequency Modulation...".postln;
    x = {
        var src = Pulse.ar(70, 0.3) * 0.25 ! 2;
        var mod = SinOsc.ar(180) * 1200;
        var sig = Dispersion.ar(src, center: 2000 + mod, spread: 1.5, q: 4.0);
        sig * 0.4;
    }.play;
    3.0.wait;
    x.free;

    "Dispersion audition complete!".postln;
});
)
