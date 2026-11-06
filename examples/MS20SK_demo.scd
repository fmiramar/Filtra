/*
    MS-20 Filter Family for SuperCollider
    Milestone 1 Demonstration: Authentic MS-20 Serial Signal Path (HP -> LP)

    In the original Korg MS-20 synthesizer, the audio signal path routes through
    the High-Pass filter FIRST, followed by the Low-Pass filter, each with its
    own independent cutoff frequency and resonance control.
*/

s.waitForBoot {
    "Starting MS-20 Filter Demonstration (HP -> LP serial cascade)...".postln;

    x = {
        // Authentic dual-oscillator / noise patch
        var osc1 = Saw.ar(55) * 0.08;
        var osc2 = Pulse.ar(55.25, 0.35) * 0.06;
        var noise = PinkNoise.ar(0.015);
        var src = osc1 + osc2 + noise;

        // Stage 1: Authentic MS-20 HPF (mode: 1)
        // High-pass cutoff removes sub-bass rumble with authentic 6 dB/oct slope
        var hpFreq = MouseY.kr(30, 1200, \exponential);
        var hpRes = 0.25;
        var hp = MS20SK.ar(src, freq: hpFreq, res: hpRes, mode: 1);

        // Stage 2: Sallen-Key Korg-35 LPF (mode: 0)
        // Low-pass sweeps down from 8000 Hz to 150 Hz with 12 dB/oct roll-off
        var lpFreq = MouseX.kr(100, 10000, \exponential);
        var lpRes = 0.65;
        var lp = MS20SK.ar(hp, freq: lpFreq, res: lpRes, mode: 0);

        (lp * 0.2) ! 2
    }.play;

    "Mouse X controls LP Cutoff (100 Hz .. 10 kHz)".postln;
    "Mouse Y controls HP Cutoff (30 Hz .. 1.2 kHz)".postln;
};
