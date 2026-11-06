/*
    Filtra - DynamicSOS Audition & Demonstration
    Modulation-Safe Cascaded Biquad (2x 2nd-order TPT SVF Sections)
    Demonstrating click-free, pop-free fast modulation across LP, HP, BP, Peak, and Shelving modes.
*/

s.boot;

(
s.waitForBoot({
    "=================================================".postln;
    "  Filtra: DynamicSOS Audition Demo              ".postln;
    "=================================================".postln;

    // 1. Audio-Rate FM Low-Pass (4-Pole 24 dB/oct)
    "Stage 1: Extreme Audio-Rate Frequency Modulation (Zero Clicks/Pops)...".postln;
    x = {
        var saw = Saw.ar([110, 110.5]) * 0.25;
        var fm = SinOsc.ar(120).exprange(150, 4500);
        var q = LFNoise1.kr(1).range(1.0, 12.0);
        var sig = DynamicSOS.ar(saw, freq: fm, q: q, mode: 0);
        sig * 0.5 ! 2;
    }.play;

    5.0.wait;
    x.free;

    // 2. Dynamic Parametric Peak EQ Sweeps
    "Stage 2: Modulated Parametric Bell EQ (+15 dB Boost Sweeps)...".postln;
    x = {
        var noise = PinkNoise.ar(0.2);
        var cut = SinOsc.kr(0.4).exprange(300, 3500);
        var boost = SinOsc.kr(0.8).range(0.0, 18.0);
        var sig = DynamicSOS.ar(noise, freq: cut, q: 6.0, gain: boost, mode: 4);
        sig * 0.5 ! 2;
    }.play;

    5.0.wait;
    x.free;

    // 3. Fast Random Stepped High-Pass Modulation
    "Stage 3: Stepped Discontinuous Cutoff Jumps (Stable Physical States)...".postln;
    x = {
        var saw = Saw.ar([80, 80.4]) * 0.3;
        var stepFreq = Demand.kr(Impulse.kr(8), 0, Dseq([150, 800, 300, 2200, 450, 4000], inf));
        var sig = DynamicSOS.ar(saw, freq: stepFreq, q: 3.0, mode: 1);
        sig * 0.5 ! 2;
    }.play;

    5.0.wait;
    x.free;

    "DynamicSOS Audition Finished!".postln;
});
)
