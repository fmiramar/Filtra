/*
    Filtra for SuperCollider
    DynamicSOS: Modulation-Safe Cascaded Biquad (2x 2nd-order TPT SVF Sections)
    Eliminates transient instability and pops during rapid coefficient modulation.
    Modes:
      0 = LowPass (24 dB/oct cascade)
      1 = HighPass (24 dB/oct cascade)
      2 = BandPass (4-pole cascade)
      3 = Notch (cascaded notch)
      4 = Peak / Bell EQ
      5 = LowShelf
      6 = HighShelf
*/

DynamicSOS : UGen {
    *ar { arg in, freq = 1000.0, q = 1.0, gain = 0.0, mode = 0, mul = 1.0, add = 0.0;
        ^this.multiNew('audio', in, freq, q, gain, mode).madd(mul, add);
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
