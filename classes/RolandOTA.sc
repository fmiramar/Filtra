/*
    Filtra for SuperCollider
    RolandOTA: Virtual Analog Model of the Roland IR3109 4-Stage OTA Cascade
    Reference: Roland Juno-6/60, Jupiter-8, and SH-101 VCF filter cores.
    Four cascaded 1-pole OTA-C integrators with global negative feedback,
    differential pair hyperbolic tangent saturation, self-oscillation limit cycle,
    and optional bass-loss compensation.
*/

RolandOTA : UGen {
    *ar { arg in, freq = 1000.0, res = 0.0, drive = 1.0, resComp = 0.0, mul = 1.0, add = 0.0;
        ^this.multiNew('audio', in, freq, res, drive, resComp).madd(mul, add);
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
