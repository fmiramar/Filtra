/*
    Filtra - CS80 Audition & Demonstration
    Yamaha CS-80 Series Independently Resonant High-Pass -> Low-Pass Filter Pair
*/

s.boot;

(
s.waitForBoot({
    "=================================================".postln;
    "  Filtra: CS80 Dual VCF Audition Demo            ".postln;
    "=================================================".postln;

    // 1. Classic CS-80 Dual-Resonant Brass Sweep
    "Stage 1: CS-80 Dual-Resonant Brass & Formant Sweep...".postln;
    x = {
        var saw = Saw.ar([55, 55.4]) * 0.25;
        // HP slowly sweeps upwards from 80 Hz to 600 Hz
        var hpCutoff = SinOsc.kr(0.1, 0).exprange(80, 600);
        // LP sweeps downwards from 6000 Hz to 1200 Hz
        var lpCutoff = SinOsc.kr(0.15, pi).exprange(1200, 6000);
        var filtered = CS80.ar(
            saw,
            hpFreq: hpCutoff,
            hpRes: 0.75,
            lpFreq: lpCutoff,
            lpRes: 0.8,
            drive: 1.5
        );
        filtered * 0.4;
    }.play;

    3.0.wait;
    x.free;

    // 2. High-Pass Formant Squelch
    "Stage 2: Independent HP Cutoff Modulation...".postln;
    x = {
        var pulse = Pulse.ar([110, 110.5], 0.3) * 0.2;
        var hpMod = LFTri.kr(0.3).exprange(100, 2000);
        CS80.ar(pulse, hpFreq: hpMod, hpRes: 0.9, lpFreq: 10000, lpRes: 0.2, drive: 2.0) * 0.4;
    }.play;

    3.0.wait;
    x.free;

    // 3. Dual Limit-Cycle Self-Oscillation
    "Stage 3: Dual Self-Oscillating Pings...".postln;
    x = {
        var trig = Impulse.ar(2);
        CS80.ar(trig * 0.5, hpFreq: 330, hpRes: 0.98, lpFreq: 1320, lpRes: 0.98, drive: 1.2) * 0.5 ! 2;
    }.play;

    3.0.wait;
    x.free;

    "CS80 Demo Finished!".postln;
});
)
