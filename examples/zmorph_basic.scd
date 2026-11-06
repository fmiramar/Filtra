/*
    Filtra - ZMorph Audition & Demonstration
    Original Digital Multiresonant Filter Response Morphing
*/

s.boot;

(
s.waitForBoot({
    "=================================================".postln;
    "  Filtra: ZMorph Audition Demo                  ".postln;
    "=================================================".postln;

    // 1. Audition Vocal Morph: Vowel A -> Vowel I
    "Stage 1: Vocal Vowel Morph (A -> I)...".postln;
    x = {
        var src = Saw.ar([110, 110.5]) * 0.25;
        var morph = SinOsc.kr(0.25).range(0.0, 1.0);
        var sig = ZMorph.ar(src, morph: morph, shapeA: 0, shapeB: 1);
        sig * 0.5;
    }.play;
    3.0.wait;
    x.free;

    // 2. Audition Comb -> Metallic Bell Morph
    "Stage 2: Comb -> Metallic Bell Morph...".postln;
    x = {
        var src = Dust2.ar(80 ! 2) * 0.5;
        var morph = LFTri.kr(0.2).range(0.0, 1.0);
        var sig = ZMorph.ar(src, morph: morph, shapeA: 3, shapeB: 4);
        sig * 0.6;
    }.play;
    3.0.wait;
    x.free;

    // 3. Audition Acoustic Body -> Vowel U Morph
    "Stage 3: Acoustic Body -> Vowel U Morph...".postln;
    x = {
        var src = Pulse.ar([82, 82.5], 0.2) * 0.25;
        var morph = XLine.kr(0.001, 0.999, 3.0);
        var sig = ZMorph.ar(src, morph: morph, shapeA: 5, shapeB: 2);
        sig * 0.5;
    }.play;
    3.0.wait;
    x.free;

    // 4. Audition Fast Audio-Rate Morph Modulation
    "Stage 4: Audio-Rate Morph Modulation...".postln;
    x = {
        var src = Saw.ar(73) * 0.25 ! 2;
        var morphMod = SinOsc.ar(110).range(0.0, 1.0);
        var sig = ZMorph.ar(src, morph: morphMod, shapeA: 1, shapeB: 4);
        sig * 0.45;
    }.play;
    3.0.wait;
    x.free;

    "ZMorph audition complete!".postln;
});
)
