/*
    Filtra for SuperCollider
    CS80: Yamaha CS-80 Series Independently Resonant High-Pass -> Low-Pass Filter Pair
    Reference: Yamaha CS-50/60/80 VCF voice architecture (IG00153 / IG00156 custom ICs).
    Cascades an independent 2-pole resonant High-Pass stage into an independent 2-pole resonant Low-Pass stage
    with inter-stage nonlinear drive saturation.
*/

CS80 : UGen {
    *ar { arg in, hpFreq = 100.0, hpRes = 0.0, lpFreq = 8000.0, lpRes = 0.0, drive = 1.0, mul = 1.0, add = 0.0;
        ^this.multiNew('audio', in, hpFreq, hpRes, lpFreq, lpRes, drive).madd(mul, add);
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
