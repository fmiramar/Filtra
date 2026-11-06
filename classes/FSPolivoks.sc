/*
    FilterSuite for SuperCollider
    FSPolivoks: Virtual Analog Model of the Formanta Polivoks VCF
    Reference: Vladimir Kuzmin (1982), Formanta Polivoks synthesizer filter core;
    Stage P1: Linearized two-stage programmable-op-amp (K140UD12 / uA776) state-variable integrator cascade.
    Modes: 0 = Low-Pass (12 dB/oct), 1 = Band-Pass (6 dB/oct).
*/

FSPolivoks : UGen {
    *ar { |in, freq = 1000.0, res = 0.3, mode = 0, drive = 1.0|
        ^this.multiNew('audio', in, freq, res, mode, drive)
    }

    checkInputs {
        if (inputs.at(0).rate != 'audio') {
            ^("FSPolivoks: first input (in) must be audio rate");
        };
        ^this.checkValidInputs;
    }
}
