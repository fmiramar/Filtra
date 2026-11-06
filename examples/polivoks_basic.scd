/*
    Filtra - Polivoks Audition & Demonstration
    Virtual Analog Model of the Formanta Polivoks VCF (Vladimir Kuzmin, 1982)
*/

s.boot;

(
s.waitForBoot({
    "=================================================".postln;
    "  Filtra: Polivoks VCF Audition Demo            ".postln;
    "=================================================".postln;

    // 1. Audition Low-Pass (LP) mode: Rich Sawtooth Sweep
    "Stage 1: Low-Pass Mode 0 (12 dB/oct roll-off)...".postln;
    x = {
        var src = Saw.ar([110, 110.5]) * 0.25;
        var cutoff = SinOsc.kr(0.2).exprange(120, 7000);
        var sig = Polivoks.ar(src, freq: cutoff, res: 0.55, mode: 0, drive: 1.0);
        sig * 0.4;
    }.play;
    2.5.wait;
    x.free;

    // 2. Audition Band-Pass (BP) mode: Resonant White Noise
    "Stage 2: Band-Pass Mode 1 (Symmetric 6 dB/oct skirts)...".postln;
    x = {
        var src = WhiteNoise.ar(0.3 ! 2);
        var cutoff = XLine.kr(300, 3500, 2.5);
        var sig = Polivoks.ar(src, freq: cutoff, res: 0.8, mode: 1, drive: 1.0);
        sig * 0.4;
    }.play;
    2.5.wait;
    x.free;

    // 3. Audition High Resonance Peaking
    "Stage 3: High-Resonance Singing Tone...".postln;
    x = {
        var pulse = Impulse.ar(2) * 0.5 ! 2;
        var sig = Polivoks.ar(pulse, freq: 880, res: 0.95, mode: 0, drive: 1.0);
        sig * 0.4;
    }.play;
    2.5.wait;
    x.free;

    // 4. Audition Fast Audio-Rate Frequency Modulation (FM)
    "Stage 4: Audio-Rate Frequency Modulation...".postln;
    x = {
        var carrier = Saw.ar(65) * 0.2 ! 2;
        var mod = SinOsc.ar(130) * 800;
        var sig = Polivoks.ar(carrier, freq: 1200 + mod, res: 0.65, mode: 0, drive: 1.0);
        sig * 0.35;
    }.play;
    2.5.wait;
    x.free;

    "Audition complete!".postln;
});
)
