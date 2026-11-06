/*
    Filtra - ChipVCF Audition & Demonstration
    Virtual Analog Model of the Solid State Micro Technology SSM2044 4-Pole Low-Pass VCF
*/

s.boot;

(
s.waitForBoot({
    "=================================================".postln;
    "  Filtra: ChipVCF (SSM2044) Audition Demo        ".postln;
    "=================================================".postln;

    // 1. Polysix Style Analog Bass Squelch
    "Stage 1: SSM2044 24 dB/oct Bass Squelch...".postln;
    x = {
        var saw = Saw.ar([55, 55.3]) * 0.3;
        var env = EnvGen.kr(Env.perc(0.01, 1.2), Impulse.kr(2));
        var cutoff = env.exprange(100, 4500);
        ChipVCF.ar(saw, freq: cutoff, res: 0.85, drive: 2.0) * 0.4 ! 2;
    }.play;

    3.0.wait;
    x.free;

    // 2. High Resonance Pure Limit Cycle
    "Stage 2: Self-Oscillation Sine Melody...".postln;
    x = {
        var trig = Impulse.ar(0);
        var pitch = Demand.kr(Impulse.kr(4), 0, Dseq([440, 660, 880, 1100], inf));
        ChipVCF.ar(trig * 0.1, freq: pitch, res: 1.05, drive: 1.0) * 0.5 ! 2;
    }.play;

    3.0.wait;
    x.free;

    "ChipVCF Demo Finished!".postln;
});
)
