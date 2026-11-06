/*
    Filtra for SuperCollider
    Wasp: Virtual Analog Model of the EDP Wasp VCF
    Reference: L. Köper, M. Holters, F. Esqueda, J. D. Parker (2022),
    "A Virtual Analog Model of the EDP Wasp VCF", DAFx 2022, Sections 2-4.
*/

Wasp : UGen {
    *ar { |in, freq = 1000.0, res = 0.2, drive = 1.0, mode = 0|
        ^this.multiNew('audio', in, freq, res, drive, mode)
    }

    checkInputs {
        if (inputs.at(0).rate != 'audio') {
            ^("Wasp: first input (in) must be audio rate");
        };
        ^this.checkValidInputs;
    }
}
