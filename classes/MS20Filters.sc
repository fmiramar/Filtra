/*
    MS-20 Filter Family for SuperCollider
    Milestone 1: MS20SK      (Linear Sallen-Key Korg-35 Model)
    Milestone 2: MS20TPT     (Zero-Delay Topology-Preserving Transform Model)
    Milestone 3: MS20Diode   (Nonlinear Korg-35 Model with Forward Amplifier Diodes)
    Milestone 4: MS20OTA     (Later Revision KLM-307 Dual OTA Filter with Feedback Diodes)
    Milestone E: MS20Circuit (Discrete BJT MNA Circuit Model with Reverse-Saturation Transistors)

    Reference: Timothy E. Stinchcombe (2006), "A Study of the Korg MS10 & MS20 Filters"
*/

MS20SK : UGen {
    *ar { |in, freq = 1000.0, res = 0.25, mode = 0|
        ^this.multiNew('audio', in, freq, res, mode)
    }

    checkInputs {
        if (inputs.at(0).rate != 'audio') {
            ^("MS20SK: first input (in) must be audio rate");
        };
        ^this.checkValidInputs;
    }
}

MS20TPT : UGen {
    *ar { |in, freq = 1000.0, res = 0.25, mode = 0|
        ^this.multiNew('audio', in, freq, res, mode)
    }

    checkInputs {
        if (inputs.at(0).rate != 'audio') {
            ^("MS20TPT: first input (in) must be audio rate");
        };
        ^this.checkValidInputs;
    }
}

MS20Diode : UGen {
    *ar { |in, freq = 1000.0, res = 0.25, drive = 1.0, mode = 0, oversample = 0|
        ^this.multiNew('audio', in, freq, res, drive, mode, oversample)
    }

    checkInputs {
        if (inputs.at(0).rate != 'audio') {
            ^("MS20Diode: first input (in) must be audio rate");
        };
        ^this.checkValidInputs;
    }
}

MS20OTA : UGen {
    *ar { |in, freq = 1000.0, res = 0.25, drive = 1.0, mode = 0, oversample = 0|
        ^this.multiNew('audio', in, freq, res, drive, mode, oversample)
    }

    checkInputs {
        if (inputs.at(0).rate != 'audio') {
            ^("MS20OTA: first input (in) must be audio rate");
        };
        ^this.checkValidInputs;
    }
}

MS20Circuit : UGen {
    *ar { |in, freq = 1000.0, res = 0.25, drive = 1.0, mode = 0, oversample = 0|
        ^this.multiNew('audio', in, freq, res, drive, mode, oversample)
    }

    checkInputs {
        if (inputs.at(0).rate != 'audio') {
            ^("MS20Circuit: first input (in) must be audio rate");
        };
        ^this.checkValidInputs;
    }
}
