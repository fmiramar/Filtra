/*
    Filtra - FormantMorph Audition & Demonstration
    Coordinated Multi-Formant Vowel Bank with Continuous Log-Frequency Trajectory Morphing
*/

s.boot;

(
s.waitForBoot({
    "=================================================".postln;
    "  Filtra: FormantMorph Vowel Audition Demo       ".postln;
    "=================================================".postln;

    // 1. Organic Vowel Morphing ([a] "father" -> [i] "bee")
    "Stage 1: Continuous Vowel Morph [a] -> [i]...".postln;
    x = {
        var saw = Saw.ar([110, 110.5]) * 0.25;
        // Smooth morph back and forth
        var morph = SinOsc.kr(0.2).range(0.0, 1.0);
        FormantMorph.ar(saw, morph: morph, vowelA: 0, vowelB: 2, freqScale: 1.0, bwScale: 1.0) * 0.5 ! 2;
    }.play;

    4.0.wait;
    x.free;

    // 2. 5-Vowel Cycle: [a] -> [e] -> [i] -> [o] -> [u]
    "Stage 2: 5-Vowel Sequence Cycle...".postln;
    x = {
        var saw = Saw.ar([82.4, 82.8]) * 0.3;
        var morph = LFTri.kr(0.4).range(0.0, 1.0);
        var vA = Demand.kr(Impulse.kr(0.8), 0, Dseq([0, 1, 2, 3, 4], inf));
        var vB = Demand.kr(Impulse.kr(0.8), 0, Dseq([1, 2, 3, 4, 0], inf));
        FormantMorph.ar(saw, morph: morph, vowelA: vA, vowelB: vB, freqScale: 1.1, bwScale: 0.8) * 0.5 ! 2;
    }.play;

    5.0.wait;
    x.free;

    "FormantMorph Demo Finished!".postln;
});
)
