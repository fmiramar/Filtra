/*
    Filtra - VCFQ Audition & Demonstration
    Serge-Style Variable-Q Ping Resonator & Multimode VCF
*/

s.boot;

(
s.waitForBoot({
    "=================================================".postln;
    "  Filtra: VCFQ (Serge Variable-Q) Audition Demo  ".postln;
    "=================================================".postln;

    // 1. Acoustic Ping Resonance (Percussion & Resonant Chimes)
    "Stage 1: Dedicated Trigger Ping Percussion (Zero Audio Input)...".postln;
    x = {
        var trig = Impulse.kr(4);
        var pitchSeq = Demand.kr(trig, 0, Dseq([220, 330, 440, 660, 550, 880, 440, 330], inf));
        var qSeq = Demand.kr(trig, 0, Dseq([10.0, 25.0, 40.0, 15.0], inf));
        // Dedicated ping excitation via trigger port
        var ping = VCFQ.ar(DC.ar(0), trig: trig, freq: pitchSeq, q: qSeq, drive: 1.5, mode: 1);
        ping * 0.4 ! 2;
    }.play;

    5.0.wait;
    x.free;

    // 2. Multimode Low-Pass & Band-Pass Dynamic Q Sweeps
    "Stage 2: Filter Sweeps with Dynamic Q Modulation...".postln;
    x = {
        var saw = Saw.ar([110, 110.5]) * 0.3;
        var cut = SinOsc.kr(0.3).exprange(200, 4500);
        var q = LFNoise2.kr(1).range(2.0, 30.0);
        var sig = VCFQ.ar(saw, trig: 0, freq: cut, q: q, drive: 2.0, mode: 0);
        sig * 0.5 ! 2;
    }.play;

    5.0.wait;
    x.free;

    // 3. Audio-Rate FM Ping Bell Synthesis
    "Stage 3: Audio-Rate FM Ping Bell Synthesis...".postln;
    x = {
        var trig = Dust.kr(3);
        var fmMod = SinOsc.ar(140).exprange(300, 1800);
        var ping = VCFQ.ar(DC.ar(0), trig: trig, freq: fmMod, q: 35.0, drive: 3.0, mode: 1);
        ping * 0.4 ! 2;
    }.play;

    5.0.wait;
    x.free;

    "VCFQ Audition Finished!".postln;
});
)
