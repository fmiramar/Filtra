/*
    FilterSuite for SuperCollider
    FSDispersion: Dispersive All-Pass Group-Delay Filter
    Reference: Abel and Smith (DAFx 2006), "Robust Design of Very High-Order Allpass Dispersion Filters"
    Four cascaded 2nd-order TPT all-pass sections with geometric frequency distribution
*/

FSDispersion : UGen {
    *ar { |in, center = 1500.0, spread = 1.0, q = 2.0|
        ^this.multiNew('audio', in, center, spread, q)
    }

    checkInputs {
        if (inputs.at(0).rate != 'audio') {
            ^("FSDispersion: first input (in) must be audio rate");
        };
        ^this.checkValidInputs;
    }
}
