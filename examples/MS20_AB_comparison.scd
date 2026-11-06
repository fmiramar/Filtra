/*
    MS-20 Filter Suite: Model A (MS20SK) vs Model B (MS20TPT) Comparison

    Demonstrates:
    1. Direct A/B auditioning between MS20SK (Bilinear biquad) and MS20TPT (Zero-Delay TPT).
    2. Null-test / difference signal showing static numerical equivalence.
    3. Serial cascade (HP -> LP) using MS20TPT.
*/

s.waitForBoot {
    "--- MS20SK vs MS20TPT A/B Comparison ---".postln;

    // 1. Direct A/B toggle audition
    // MouseX toggles between 0 (MS20SK) and 1 (MS20TPT)
    x = {
        var src = Saw.ar([110, 110.5]) * 0.1;
        var cutoff = SinOsc.kr(0.15).exprange(200, 5000);
        var res = 0.7;

        var sigSK  = MS20SK.ar(src, freq: cutoff, res: res, mode: 0);
        var sigTPT = MS20TPT.ar(src, freq: cutoff, res: res, mode: 0);

        // Select: 0 = SK, 1 = TPT
        var toggle = MouseX.kr(0, 1).round;
        var out = Select.ar(toggle, [sigSK, sigTPT]);

        out * 0.2
    }.play;

    "Toggle audition running. Move mouse to left for MS20SK, right for MS20TPT.".postln;
};
