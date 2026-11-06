/*
    Filtra - NLMS Audition & Demonstration
    Real-Time Adaptive Normalized Least-Mean-Squares FIR Filter
*/

s.boot;

(
s.waitForBoot({
    "=================================================".postln;
    "  Filtra: NLMS Adaptive Filter Audition Demo     ".postln;
    "=================================================".postln;

    // 1. Acoustic System Identification & Echo Cancellation
    "Stage 1: System Identification & Noise Cancellation...".postln;
    x = {
        // Reference signal: broad-spectrum pink noise
        var ref = PinkNoise.ar(0.3);
        // Unknown target system: 3 resonant reflections
        var target = CombN.ar(ref, 0.02, [0.003, 0.007], 0.2).sum * 0.5;
        // Adaptive filter identifies the system and cancels the echoes
        var sigs = NLMS.ar(ref, target, mu: 0.1, eps: 0.001);
        var estimated = sigs[0];
        var residualError = sigs[1];

        // Left: target with echo, Right: residual error (cancellation)
        [target, residualError] * 0.4;
    }.play;

    4.0.wait;
    x.free;

    "NLMS Demo Finished!".postln;
});
)
