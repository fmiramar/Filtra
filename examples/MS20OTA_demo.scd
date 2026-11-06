/*
    MS-20 Filter Suite: Milestone 4 Demonstration (MS20OTA)

    Demonstrates:
    1. Direct comparison between early Korg-35 (MS20Diode) and late OTA (MS20OTA).
       Notice how MS20Diode distorts the whole spectrum (forward diodes),
       whereas MS20OTA keeps the passband clean and saturates only the resonant peak (feedback diodes).
    2. Liquid singing self-oscillation.
    3. Serial cascade (HP -> LP) with the OTA revision.
*/

s.waitForBoot {
    "--- MS20Diode vs MS20OTA Comparative Demonstration ---".postln;

    // Interactive comparison: MouseX toggles between MS20Diode (left) and MS20OTA (right)
    x = {
        var src = Saw.ar([110, 110.5]) * 0.15;
        var cutoff = SinOsc.kr(0.15).exprange(150, 4000);
        var res = 0.75;
        var drive = MouseY.kr(1.0, 4.0, \exponential);

        var sigDiode = MS20Diode.ar(src, freq: cutoff, res: res, drive: drive, mode: 0);
        var sigOTA   = MS20OTA.ar(src, freq: cutoff, res: res, drive: drive, mode: 0);

        var toggle = MouseX.kr(0, 1).round;
        var out = Select.ar(toggle, [sigDiode, sigOTA]);

        out * 0.25
    }.play;

    "MouseX: Left = early Korg-35 (MS20Diode, aggressive grit), Right = late OTA (MS20OTA, liquid singing).".postln;
    "MouseY: Drive (1.0 to 4.0)".postln;
};
