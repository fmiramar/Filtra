/*
    Filtra for SuperCollider
    VCFQ: Serge-Style Variable-Q Ping Resonator & Multimode VCF
    Reference: Serge Tcherepnin VCFQ modular synthesizer filter core.
    2-pole TPT state-variable filter with dedicated trigger/impulse ping excitation,
    dynamic Q control, and nonlinear AGC diode feedback saturation.
    Modes: 0 = Low-Pass, 1 = Band-Pass (classic ping), 2 = High-Pass, 3 = Notch.
*/

VCFQ : UGen {
    *ar { arg in, trig = 0.0, freq = 1000.0, q = 5.0, drive = 1.0, mode = 1, mul = 1.0, add = 0.0;
        ^this.multiNew('audio', in, trig, freq, q, drive, mode).madd(mul, add);
    }

    checkInputs {
        if (rate == 'audio') {
            if (inputs.at(0).rate != 'audio') {
                ^(": audio rate input required for in");
            };
        };
        ^this.checkValidInputs;
    }
}
