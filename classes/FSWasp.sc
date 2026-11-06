/*
    FilterSuite for SuperCollider
    FSWasp: Virtual Analog Model of the EDP Wasp VCF (Stage W1: Linear Small-Signal)
    Reference: L. Köper, M. Holters, F. Esqueda, J. D. Parker (2022),
    "A Virtual Analog Model of the EDP Wasp VCF", DAFx 2022, Sections 2-3.
*/

FSWasp : UGen {
    *ar { |in, freq = 1000.0, res = 0.2, drive = 1.0, mode = 0|
        ^this.multiNew('audio', in, freq, res, drive, mode)
    }

    checkInputs {
        if (inputs.at(0).rate != 'audio') {
            ^("FSWasp: first input (in) must be audio rate");
        };
        ^this.checkValidInputs;
    }
}
