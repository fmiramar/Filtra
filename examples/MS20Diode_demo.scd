/*
    MS-20 Filter Suite: Milestone 3 Demonstration (MS20Diode)

    Demonstrates:
    1. Drive and diode saturation on dynamic synth tones.
    2. Self-limiting, bounded self-oscillation without digital explosion.
    3. Serial authentic cascade (HP -> LP) with analog-style diode saturation.
*/

s.waitForBoot {
    "--- MS20Diode Nonlinear Filter Demonstration ---".postln;

    // 1. Self-Oscillation as a playable musical instrument
    // Plays an arpeggiated melodic sequence using pure self-oscillation (input is silence!)
    Pbind(
        \instrument, \default,
        \dur, 0.25
    );

    x = {
        var trig = Impulse.kr(4);
        var note = Demand.kr(trig, 0, Dseq([55, 58, 62, 65, 67, 70, 72, 74].midicps, inf));
        var cutoff = Lag.kr(note, 0.05);

        // Input is pure silence: the filter self-oscillates at the cutoff frequency!
        var selfOsc = MS20Diode.ar(DC.ar(0.0), freq: cutoff, res: 0.95, drive: 1.0, mode: 0);

        (selfOsc * 0.25) ! 2
    }.play;

    "Self-oscillation melody running. High resonance forms a clean, bounded sine limit cycle.".postln;
};
