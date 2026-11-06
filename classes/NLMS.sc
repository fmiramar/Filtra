/*
    Filtra for SuperCollider
    NLMS: Real-Time Adaptive Normalized Least-Mean-Squares FIR Filter
    Reference: Haykin, Adaptive Filter Theory; Widrow & Stearns.
    Adapts a 32-tap FIR filter in real time to estimate a target desired signal and minimize residual error.
    Outputs: [0] = estimated signal y[n], [1] = residual error e[n].
*/

NLMS : MultiOutUGen {
    *ar { arg reference, desired, mu = 0.05, eps = 0.001;
        ^this.multiNew('audio', reference, desired, mu, eps);
    }

    init { arg ... theInputs;
        inputs = theInputs;
        ^this.initOutputs(2, rate);
    }

    checkInputs {
        if (inputs.at(0).rate != 'audio') {
            ^(": audio rate input required for reference");
        };
        if (inputs.at(1).rate != 'audio') {
            ^(": audio rate input required for desired");
        };
        ^this.checkValidInputs;
    }
}
