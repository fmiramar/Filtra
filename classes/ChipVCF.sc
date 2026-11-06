/*
    Filtra for SuperCollider
    ChipVCF: Virtual Analog Model of the Solid State Micro Technology SSM2044 4-Pole Low-Pass VCF
    Reference: SSM2044 datasheet, Korg Polysix, Korg Mono/Poly, and PPG Wave VCF cores.
    4-stage buffered differential ladder with internal gain-cell feedback saturation,
    partial bass-loss compensation, and singing sinusoidal limit cycle.
*/

ChipVCF : UGen {
    *ar { arg in, freq = 1000.0, res = 0.0, drive = 1.0, mul = 1.0, add = 0.0;
        ^this.multiNew('audio', in, freq, res, drive).madd(mul, add);
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
