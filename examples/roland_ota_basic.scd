/*
    Filtra - RolandOTA Audition & Demonstration
    Virtual Analog Model of the Roland IR3109 4-Stage OTA Cascade (Juno-60 / Jupiter-8)
*/

s.boot;

(
s.waitForBoot({
    "=================================================".postln;
    "  Filtra: RolandOTA VCF Audition Demo            ".postln;
    "=================================================".postln;

    // 1. Classic Juno/Jupiter 24 dB/oct Low-Pass Acid Sweep
    "Stage 1: Authentic Roland 4-pole Low-Pass Sweep...".postln;
    x = {
        var saw = Saw.ar([110, 110.5]) * 0.25;
        var cutoff = SinOsc.kr(0.2).exprange(150, 4500);
        RolandOTA.ar(saw, freq: cutoff, res: 0.85, drive: 1.5, resComp: 0.0) * 0.4;
    }.play;

    3.0.wait;
    x.free;

    // 2. Bass Compensation Comparison (resComp = 0 vs 1)
    "Stage 2: Bass Drop (resComp=0) vs Bass Boosted (resComp=1)...".postln;
    x = {
        var bass = Pulse.ar(55, 0.4) * 0.3 ! 2;
        var toggle = LFPulse.kr(0.5); // alternates every 2 seconds
        var filtered = RolandOTA.ar(bass, freq: 800, res: 0.9, drive: 1.0, resComp: toggle);
        filtered * 0.4;
    }.play;

    4.0.wait;
    x.free;

    // 3. Pure Sinusoidal Limit-Cycle Self-Oscillation
    "Stage 3: Roland Singing Self-Oscillation Sine...".postln;
    x = {
        var trig = Impulse.ar(0);
        var pitch = Demand.kr(Impulse.kr(4), 0, Dseq([440, 554.37, 659.25, 880], inf));
        RolandOTA.ar(trig * 0.1, freq: pitch, res: 1.05, drive: 1.0) * 0.5 ! 2;
    }.play;

    4.0.wait;
    x.free;

    "RolandOTA Demo Finished!".postln;
});
)
