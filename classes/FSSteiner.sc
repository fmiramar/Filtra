/*
    FilterSuite for SuperCollider
    FSSteiner: Virtual Analog Model of the Steiner-Parker Multimode Diode VCF
    Reference: Nyle Steiner (Electronic Design, 1974), "Voltage-tunable active filter features
    low, high and bandpass modes", and Yves Usson (YuSynth 2004) diode-limited Sallen-Key topology.
*/

FSSteiner : UGen {
    *ar { |in, freq = 1000.0, res = 0.3, mode = 0, drive = 1.0|
        ^this.multiNew('audio', in, freq, res, mode, drive)
    }

    checkInputs {
        if (inputs.at(0).rate != 'audio') {
            ^("FSSteiner: first input (in) must be audio rate");
        };
        ^this.checkValidInputs;
    }
}
